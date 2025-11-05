# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queries
      class Code
        include Gitlab::Loggable

        KNN_COUNT = 10
        SEARCH_RESULTS_LIMIT = 10
        COLLECTION_CLASS = ::Ai::ActiveContext::Collections::Code

        LAST_QUERIED_UPDATE_INTERVAL = 1.hour

        MESSAGE_INITIAL_INDEXING_STARTED = 'initial indexing has been started, try again in a few minutes'
        MESSAGE_INITIAL_INDEXING_ONGOING = 'initial indexing is still ongoing, try again in a few minutes'
        MESSAGE_ADHOC_INDEXING_TRIGGER_FAILED = 'initial indexing was attempted but could not be started'
        MESSAGE_INDEXING_FAILED = 'indexing failed'

        NotAvailable = Class.new(StandardError)

        def self.available?
          COLLECTION_CLASS.indexing? &&
            COLLECTION_CLASS.collection_record.present?
        end

        def initialize(search_term:, user:)
          @search_term = search_term
          @user = user
        end

        def filter(
          project_id:,
          path: nil,
          knn_count: KNN_COUNT,
          limit: SEARCH_RESULTS_LIMIT,
          exclude_fields: [],
          extract_source_segments: false
        )
          check_availability

          ac_repository = find_active_context_repository(project_id)
          return handle_no_ready_active_context_repository(project_id, ac_repository) unless ac_repository&.ready?

          # Update the last queried timestamp so that we can potentially prune inactive data later
          update_last_queried_timestamp(ac_repository)

          query = if path.nil?
                    repository_query(project_id, knn_count, limit)
                  else
                    directory_query(project_id, path, knn_count, limit)
                  end

          search_hits = COLLECTION_CLASS.search(query: query, user: user)

          Result.success(
            prepare_hits(
              search_hits, exclude_fields: exclude_fields, extract_source_segments: extract_source_segments
            )
          )
        end

        private

        attr_reader :user, :search_term

        def handle_no_ready_active_context_repository(project_id, ac_repository)
          error_detail = nil

          if ac_repository.nil?
            ad_hoc_indexing = try_trigger_ad_hoc_indexing(project_id)
            error_detail = ad_hoc_indexing ? MESSAGE_INITIAL_INDEXING_STARTED : MESSAGE_ADHOC_INDEXING_TRIGGER_FAILED
          elsif ac_repository.failed?
            error_detail = MESSAGE_INDEXING_FAILED
          else
            error_detail = MESSAGE_INITIAL_INDEXING_ONGOING
          end

          Result.no_embeddings_error(error_detail: error_detail)
        end

        def try_trigger_ad_hoc_indexing(project_id)
          Ai::ActiveContext::Code::AdHocIndexingWorker.perform_async(project_id)
        rescue StandardError => e
          logger.warn(
            build_structured_payload(
              message: "Failed to trigger ad-hoc indexing",
              exception_class: e.class.name,
              exception_message: e.message,
              project_id: project_id
            )
          )

          false
        end

        def update_last_queried_timestamp(ac_repository)
          # Do not update if `last_queried_at` is nil, or it was updated within the set interval
          return if ac_repository.last_queried_at.present? &&
            ac_repository.last_queried_at > LAST_QUERIED_UPDATE_INTERVAL.ago

          ac_repository.update_last_queried_timestamp
        rescue ActiveRecord::ActiveRecordError => e
          logger.warn(
            build_structured_payload(
              message: "Failed to update last_queried_at",
              exception_class: e.class.name,
              exception_message: e.message,
              ai_active_context_code_repository_id: ac_repository.id,
              project_id: ac_repository.project_id
            )
          )
        end

        def prepare_hits(search_hits, exclude_fields: [], extract_source_segments: false)
          search_hits.map do |hit|
            item = hit.except(*exclude_fields)

            # The source is defined here:
            # https://gitlab.com/gitlab-org/gitlab-elasticsearch-indexer/-/blob/main/internal/mode/chunk/chunker/types.go
            # eg, fmt.Sprintf("%s::%d:%d::%d", c.OID, c.StartByte, c.Length, c.StartLine)
            if extract_source_segments
              src = hit['source']
              src_matched_segments = src.is_a?(String) && src.match(/\A([0-9a-f]{40})::(\d+):(\d+)::(\d+)\z/i)

              if src_matched_segments
                item['blob_id'] = src_matched_segments[1]
                item['start_byte'] = src_matched_segments[2].to_i
                item['length'] = src_matched_segments[3].to_i
                item['start_line'] = src_matched_segments[4].to_i
              end
            end

            item
          end
        end

        def check_availability
          return if self.class.available?

          raise(
            NotAvailable,
            "Semantic search on Code collection is not available."
          )
        end

        # rubocop: disable CodeReuse/ActiveRecord -- no need to redefine a scope for the built-in method
        def find_active_context_repository(project_id)
          Ai::ActiveContext::Code::Repository.find_by(
            project_id: project_id,
            connection_id: collection_record.connection_id
          )
        end
        # rubocop: enable CodeReuse/ActiveRecord

        def repository_query(project_id, knn_count, limit)
          ::ActiveContext::Query.filter(
            project_id: project_id
          ).knn(
            target: current_embeddings_field,
            vector: target_embeddings,
            k: knn_count
          ).limit(
            limit
          )
        end

        def directory_query(project_id, path, knn_count, limit)
          ::ActiveContext::Query.and(
            ::ActiveContext::Query.filter(project_id: project_id),
            ::ActiveContext::Query.prefix(path: path_with_trailing_slash(path))
          ).knn(
            target: current_embeddings_field,
            vector: target_embeddings,
            k: knn_count
          ).limit(
            limit
          )
        end

        def path_with_trailing_slash(path)
          path.ends_with?("/") ? path : "#{path}/"
        end

        def target_embeddings
          @target_embeddings ||= generate_target_embeddings
        end

        def generate_target_embeddings
          ::ActiveContext::Embeddings.generate_embeddings(
            search_term,
            unit_primitive: embeddings_unit_primitive,
            version: current_embeddings_version
          ).first
        end

        def embeddings_unit_primitive
          ::Ai::ActiveContext::References::Code::UNIT_PRIMITIVE
        end

        def current_embeddings_version
          @current_embeddings_version ||= COLLECTION_CLASS.current_search_embedding_version
        end

        def current_embeddings_field
          current_embeddings_version[:field]
        end

        def collection_record
          @collection_record ||= COLLECTION_CLASS.collection_record
        end

        def logger
          @logger ||= ::ActiveContext::Config.logger
        end
      end
    end
  end
end
