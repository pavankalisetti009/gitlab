# frozen_string_literal: true

module Ai
  module ActiveContext
    module Collections
      class Code
        include ::ActiveContext::Concerns::Collection

        # We have calculated an average about 500 tokens per chunk
        # Vertex AI API limits 20,000 tokens per request
        # Each embeddings generation request should have a batch size of:
        # 20,000 / 50 = 40
        # Details: https://gitlab.com/gitlab-org/gitlab/-/issues/551002#note_2595329124
        EMBEDDINGS_V1_BATCH_SIZE = 40

        MODELS = {
          1 => {
            field: :embeddings_v1,
            model: 'text-embedding-005',
            class: Ai::ActiveContext::Embeddings::Code::VertexText,
            batch_size: EMBEDDINGS_V1_BATCH_SIZE
          }
        }.freeze

        def self.indexing?
          ::ActiveContext.indexing? && current_indexing_embedding_versions.present?
        end

        def self.collection_name
          ::ActiveContext.adapter.full_collection_name('code')
        end

        def self.queue
          Queues::Code
        end

        def self.reference_klass
          References::Code
        end

        def self.partition_name
          collection_record.name
        end

        def self.partition_number(project_id)
          collection_record.partition_for(project_id)
        end

        def self.routing(object)
          object[:routing]
        end

        # TODO: this is a temporary override while we are working on supporting self-hosted AIGW setups
        # See https://gitlab.com/groups/gitlab-org/-/work_items/20110
        def self.current_indexing_embedding_versions
          return [] unless use_gitlab_selected_model?

          super
        end

        # TODO: this is a temporary override while we are working on supporting self-hosted AIGW setups
        # See https://gitlab.com/groups/gitlab-org/-/work_items/20110
        def self.current_search_embedding_version
          return {} unless use_gitlab_selected_model?

          super
        end

        def self.track_refs!(routing:, hashes:)
          hashes.each { |hash| track!({ id: hash, routing: routing }) }
        end

        def self.redact_unauthorized_results!(result)
          return result if result.user.nil?

          project_ids = result.pluck('project_id') # rubocop: disable CodeReuse/ActiveRecord -- this an enum `pluck` method, not ActiveRecord
          projects = Project.id_in(project_ids).index_by(&:id)

          result.group_by { |r| r['project_id'] }.each_with_object([]) do |(project_id, project_objects), permitted|
            project = projects[project_id]

            permitted.concat(project_objects) if project && Ability.allowed?(result.user, :read_code, project)
          end
        end

        def self.use_gitlab_selected_model?
          ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions) ||
            ::Gitlab::CurrentSettings.gitlab_dedicated_instance? ||
            !::Gitlab::AiGateway.has_self_hosted_ai_gateway?
        end
        private_class_method :use_gitlab_selected_model?
      end
    end
  end
end
