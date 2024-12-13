# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module SelfHostedModels
        module Tasks
          class ModelConnectionTest < ::CodeSuggestions::Tasks::CodeCompletion
            def initialize(unsafe_passthrough_params:, self_hosted_model:)
              @model_details = TestedModelDetails.new(current_user: current_user, self_hosted_model: self_hosted_model)
              super(unsafe_passthrough_params: unsafe_passthrough_params)
            end
          end
        end
      end
    end
  end
end
