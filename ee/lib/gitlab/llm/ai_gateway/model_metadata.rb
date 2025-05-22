# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      class ModelMetadata
        def initialize(feature_setting: nil)
          @feature_setting = feature_setting
        end

        def to_params
          return namespace_settings_params if feature_setting.is_a?(::Ai::ModelSelection::NamespaceFeatureSetting)

          return self_hosted_params if feature_setting&.self_hosted?

          amazon_q_params if ::Ai::AmazonQ.connected?
        end

        def self_hosted_params
          self_hosted_model = feature_setting&.self_hosted_model

          return unless self_hosted_model

          {
            provider: self_hosted_model.provider,
            name: self_hosted_model.model,
            endpoint: self_hosted_model.endpoint,
            api_key: self_hosted_model.api_token,
            identifier: self_hosted_model.identifier
          }
        end

        private

        attr_reader :feature_setting

        def namespace_settings_params
          {
            provider: feature_setting.provider,
            identifier: feature_setting.offered_model_ref,
            feature_setting: feature_setting.feature
          }
        end

        def amazon_q_params
          {
            provider: :amazon_q,
            name: :amazon_q,
            role_arn: ::Ai::Setting.instance.amazon_q_role_arn
          }
        end
      end
    end
  end
end
