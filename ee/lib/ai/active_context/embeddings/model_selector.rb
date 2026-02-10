# frozen_string_literal: true

module Ai
  module ActiveContext
    module Embeddings
      class ModelSelector
        MissingModelDefinition = Class.new(StandardError)
        UnexpectedModelConfiguration = Class.new(StandardError)

        # We have calculated an average about 500 tokens per chunk
        # Vertex AI API limits 20,000 tokens per request
        # Each embeddings generation request should have a batch size of:
        # 20,000 / 50 = 40
        # Details: https://gitlab.com/gitlab-org/gitlab/-/issues/551002#note_2595329124
        TEXT_EMBEDDING_VERTEX_BATCH_SIZE = 40

        # The key for this lookup corresponds to the `model_ref` in the collection record metadata.
        # The format has to follow the convention in AIGW's `ai_gateway/model_selection/models.yml`,
        #   which is the global registry for GitLab-managed models.
        # Once we implement the specialized `/embeddings` endpoint in AIGW,
        #   we will add embedding model definitions to the `ai_gateway/model_selection/models.yml`.
        #   For GitLab-managed models, the `/embeddings` endpoint will refer to this yaml file
        #   to determine the model and provider given the `model_ref`.
        # The `model` value in this lookup is needed because we are still using the Vertex Proxy API.
        # Related work items:
        #   - https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/work_items/1866
        #   - https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/work_items/1879
        MODELS_LOOKUP = {
          'text_embedding_005_vertex' => {
            model: 'text-embedding-005',
            llm_class: Ai::ActiveContext::Embeddings::Code::VertexText,
            batch_size: TEXT_EMBEDDING_VERTEX_BATCH_SIZE
          }
        }.freeze

        def self.use_gitlab_selected_model?
          ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions) ||
            ::Gitlab::CurrentSettings.gitlab_dedicated_instance? ||
            !::Gitlab::AiGateway.has_self_hosted_ai_gateway?
        end

        def self.for(model_metadata)
          new(model_metadata).execute
        end

        def initialize(model_metadata)
          @model_metadata = model_metadata
        end

        def execute
          # User-selected models are only available in a self-hosted AIGW setup
          # Support for self-hosted AIGW setup will be added starting
          # with self-hosted models (https://gitlab.com/gitlab-org/gitlab/-/issues/588849)
          return unless self.class.use_gitlab_selected_model?

          return if model_metadata.nil?

          validate_model_metadata!

          gitlab_managed_model
        end

        private

        attr_reader :model_metadata

        def gitlab_managed_model
          validate_gitlab_model_definition!

          ::ActiveContext::EmbeddingModel.new(
            model_name: gitlab_model_definition[:model],
            field: model_metadata[:field],
            llm_class: gitlab_model_definition[:llm_class],
            llm_params: {
              model: gitlab_model_definition[:model],
              batch_size: gitlab_model_definition[:batch_size]
            }
          )
        end

        def model_ref
          @model_ref ||= model_metadata[:model_ref]
        end

        def gitlab_model_definition
          @gitlab_model_definition ||= MODELS_LOOKUP[model_ref]
        end

        def validate_model_metadata!
          return if model_metadata[:model_ref].present? && model_metadata[:field].present?

          raise UnexpectedModelConfiguration, "`model_metadata` must have a `model_ref` and `field`"
        end

        def validate_gitlab_model_definition!
          return if gitlab_model_definition.present?

          raise MissingModelDefinition, "Missing definitions for Gitlab-managed model: #{model_ref}"
        end
      end
    end
  end
end
