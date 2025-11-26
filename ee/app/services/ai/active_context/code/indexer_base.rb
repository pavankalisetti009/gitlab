# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class IndexerBase
        include Gitlab::Utils::StrongMemoize
        include Gitlab::Loggable

        TIMEOUT = '30m'
        Error = Class.new(StandardError)

        def initialize(active_context_repository)
          # `active_context_repository` refers to `Ai::ActiveContext::Code::Repository`
          # object used for tracking the state of embeddings indexing for a project
          # `project_repository` refers to the `Repository` object that points to the
          # actual git repository in Gitaly.
          @active_context_repository = active_context_repository
          @project = active_context_repository.project
          @project_repository = project&.repository
        end

        private

        attr_reader :active_context_repository, :project, :project_repository

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
        # This method converts various URL formats into the required string array format
        # and filters connection options to only those expected by the adapter:
        # - ElasticsearchConnection: only 'url'
        # - OpenSearchConnection: 'url', 'aws', 'aws_region', 'aws_access_key', etc.
        def elasticsearch_connection_options
          options = adapter.connection.options.symbolize_keys

          { url: normalize_urls(options[:url]) }.merge(aws_connection_options(options))
        end

        def normalize_urls(urls)
          Array(urls).map do |url|
            url.is_a?(Hash) ? Addressable::URI.new(url.symbolize_keys).normalize.to_s : url
          end
        end

        def aws_connection_options(options)
          return {} unless options[:aws]

          options.slice(
            :aws, :aws_region, :aws_access_key, :aws_secret_access_key, :aws_role_arn, :client_request_timeout
          ).compact
        end

        def base_options
          {
            project_id: active_context_repository.project_id,
            partition_name: collection_class.partition_name,
            partition_number: collection_class.partition_number(active_context_repository.project_id),
            timeout: TIMEOUT
          }
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
            project_id: active_context_repository.project_id
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
