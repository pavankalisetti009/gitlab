# frozen_string_literal: true

module Ai
  module Catalog
    module DuoWorkflowPayloadBuilder
      class ChatFlow < ExperimentalAgentWrapper
        include Gitlab::Utils::StrongMemoize
        extend ::Gitlab::Utils::Override

        FLOW_ENVIRONMENT = 'chat-partial'

        private

        override :build_flow_config
        def build_flow_config
          {
            'version' => FLOW_VERSION,
            'environment' => FLOW_ENVIRONMENT,
            'components' => build_components,
            'routers' => [],
            'flow' => {},
            'prompts' => build_prompt_components,
            'params' => { 'timeout' => DUO_FLOW_TIMEOUT }
          }
        end

        override :user_prompt
        def user_prompt(_definition)
          'Here is my task - {{goal}}'
        end
      end
    end
  end
end
