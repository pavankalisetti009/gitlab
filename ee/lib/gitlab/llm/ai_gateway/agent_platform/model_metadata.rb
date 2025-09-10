# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module AgentPlatform
        class ModelMetadata
          def initialize(feature_setting:)
            @feature_setting = feature_setting
          end

          def execute
            model_metadata = ::Gitlab::Llm::AiGateway::ModelMetadata.new(feature_setting: feature_setting).to_params
            return {} unless model_metadata.present?

            { 'x-gitlab-agent-platform-model-metadata' => model_metadata.to_json }
          end

          private

          attr_reader :feature_setting
        end
      end
    end
  end
end
