# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class Indexer
        include Gitlab::Utils::StrongMemoize
        include Gitlab::Loggable

        TIMEOUT = '30m'
        Error = Class.new(StandardError)

        def self.run!(active_context_repository, &block)
          new(active_context_repository).run(&block)
        end

        def initialize(active_context_repository)
          # `active_context_repository` refers to `Ai::ActiveContext::Code::Repository`
          # object used for tracking the state of embeddings indexing for a project
          # `project_repository` refers to the `Repository` object that points to the
          # actual git repository in Gitaly.
          @active_context_repository = active_context_repository
          @project = active_context_repository.project
          @project_repository = project.repository
        end

        def run(&block)
          raise Error, 'Adapter not set' unless adapter

          # determine the commit-related values at the beginning of indexing
          # to ensure we are logging the correct values
          determine_shas_and_force_reindex_flag

          response_processor = IndexerResponseModifier.new(&block)
          stderr_output = []

          status = log_duration('Run indexer') do
            Gitlab::Popen.popen_with_streaming(command, nil, environment_variables) do |stream_type, line|
              case stream_type
              when :stdout
                response_processor.process_line(line)
              when :stderr
                stderr_output << line
              end
            end
          end

          unless status == 0
            log_error(
              "Indexer failed",
              status: status,
              error_details: stderr_output.join
            )
            raise Error, "Indexer failed with status: #{status} and error: #{stderr_output.join}"
          end

          log_info('Indexer successful', status: status)

          active_context_repository.update!(last_commit: to_sha)
        end

        private

        attr_reader :active_context_repository, :project, :project_repository, :from_sha, :to_sha, :force_reindex

        def determine_shas_and_force_reindex_flag
          @to_sha = project_repository.commit&.id
          raise Error, "Project repository commit not found" unless @to_sha

          if force_push?
            @from_sha = ""
            @force_reindex = true
            return
          end

          @from_sha = last_indexed_commit
          @force_reindex = false
        end

        def force_push?
          return false if Feature.disabled?(:active_context_code_indexer_check_force_push, project)

          if last_indexed_commit.blank? ||
              Gitlab::Git.blank_ref?(last_indexed_commit) ||
              last_indexed_commit == project_repository.empty_tree_id
            return false
          end

          # force-push if the last_indexed_commit is no longer reachable in the repository
          return true unless git_repository_contains_last_indexed_commit?

          # force-push if the last_indexed_commit is NOT an ancestor of the to_sha (latest commit)
          !last_indexed_commit_ancestor_of_to_sha?
        end

        def last_indexed_commit
          @last_indexed_commit ||= active_context_repository.last_commit
        end

        def git_repository_contains_last_indexed_commit?
          log_duration('git_repository_contains_last_indexed_commit?') do
            last_indexed_commit.present? && project_repository.commit(last_indexed_commit).present?
          end
        end

        def last_indexed_commit_ancestor_of_to_sha?
          log_duration('last_indexed_commit_ancestor_of_to_sha?') do
            project_repository.ancestor?(last_indexed_commit, to_sha)
          end
        end

        def command
          [
            Gitlab.config.elasticsearch.indexer_path,
            '-adapter', adapter.name,
            '-connection', ::Gitlab::Json.generate(connection),
            '-options', ::Gitlab::Json.generate(options)
          ]
        end

        def environment_variables
          { 'GITLAB_INDEXER_MODE' => 'chunk' }
        end

        def connection
          if Ai::ActiveContext::Connection::ADAPTERS_FOR_ADVANCED_SEARCH.include?(adapter.class)
            return elasticsearch_connection_options
          end

          adapter.connection.options
        end

        # gitlab-elasticsearch-indexer requires connection as { url: ['string1', 'string2'] }
        # This method converts various URL formats into the required string array format.
        def elasticsearch_connection_options
          urls = Array(adapter.connection.options.symbolize_keys[:url]).map do |url|
            url.is_a?(Hash) ? Addressable::URI.new(url.symbolize_keys).normalize.to_s : url
          end

          { url: urls }
        end

        def options
          {
            project_id: project.id,
            from_sha: from_sha,
            to_sha: to_sha,
            force_reindex: force_reindex,
            partition_name: collection_class.partition_name,
            partition_number: collection_class.partition_number(project.id),
            gitaly_config: gitaly_config,
            timeout: TIMEOUT
          }
        end

        def gitaly_config
          {
            storage: project.repository_storage,
            relative_path: project_repository.relative_path,
            project_path: project.full_path
          }.merge(Gitlab::GitalyClient.connection_data(project.repository_storage))
        end

        def collection_class
          ::Ai::ActiveContext::Collections::Code
        end

        def adapter
          ::ActiveContext.adapter
        end
        strong_memoize_attr :adapter

        def log_duration(message, extra_params = {})
          result = nil

          duration = Benchmark.realtime do
            result = yield
          end

          extra_params[:duration_s] = duration.round(2)
          log_info(message, extra_params)

          result
        end

        def log_info(message, extra_params = {})
          logger.info(build_log_payload(message, extra_params))
        end

        def log_error(message, extra_params = {})
          logger.error(build_log_payload(message, extra_params))
        end

        def build_log_payload(message, extra_params = {})
          params = {
            message: message,
            ai_active_context_code_repository_id: active_context_repository.id,
            project_id: project.id,
            from_sha: from_sha,
            to_sha: to_sha
          }.merge(extra_params)

          build_structured_payload(**params)
        end

        def logger
          @logger ||= ::ActiveContext::Config.logger
        end
      end
    end
  end
end
