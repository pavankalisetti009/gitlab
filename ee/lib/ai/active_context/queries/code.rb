# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queries
      class Code
        KNN_COUNT = 10
        SEARCH_RESULTS_LIMIT = 10
        COLLECTION_CLASS = ::Ai::ActiveContext::Collections::Code

        NoCollectionRecordError = Class.new(StandardError)

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
          extract_source_segments: false)
          raise(NoCollectionRecordError, "A Code collection record is required.") if no_collection_record?

          query = if path.nil?
                    repository_query(project_id, knn_count, limit)
                  else
                    directory_query(project_id, path, knn_count, limit)
                  end

          results = COLLECTION_CLASS.search(query: query, user: user)

          present_results(results, exclude_fields: exclude_fields, extract_source_segments: extract_source_segments)
        end

        private

        attr_reader :user, :search_term

        def present_results(results, exclude_fields: [], extract_source_segments: false)
          results.map do |hit|
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

        def no_collection_record?
          COLLECTION_CLASS.collection_record.nil?
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
      end
    end
  end
end
