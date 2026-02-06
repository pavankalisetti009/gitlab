# frozen_string_literal: true

module Ai
  module ActiveContext
    module Embeddings
      class ModelSelector
        def self.use_gitlab_selected_model?
          ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions) ||
            ::Gitlab::CurrentSettings.gitlab_dedicated_instance? ||
            !::Gitlab::AiGateway.has_self_hosted_ai_gateway?
        end
      end
    end
  end
end
