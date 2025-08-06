# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      module SelfHosted
        class Vendored < CodeSuggestions::Prompts::Base
          include ::Ai::ModelSelection::Concerns::GitlabDefaultModelParams

          def request_params
            params_as_if_gitlab_default_model(
              ::CodeSuggestions::ModelDetails::CodeCompletion::FEATURE_SETTING_NAME
            )
          end
        end
      end
    end
  end
end
