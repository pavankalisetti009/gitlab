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

          @target_embeddings = nil
        end

        def filter(project_id:)
          if no_collection_record?
            raise(
              NoCollectionRecordError,
              "A Code collection record is required."
            )
          end

          query = ::ActiveContext::Query.filter(
            project_id: project_id
          ).knn(
            target: current_embeddings_field,
            vector: target_embeddings,
            limit: KNN_COUNT
          ).limit(
            SEARCH_RESULTS_LIMIT
          )

          COLLECTION_CLASS.search(query: query, user: user)
        end

        private

        attr_reader :search_term, :user

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
            model: current_embeddings_model
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

        def current_embeddings_model
          current_embeddings_version[:model]
        end
      end
    end
  end
end
