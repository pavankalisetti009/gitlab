# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      # Performs a real request using the current user to verify that AI features work.
      class EndToEndProbe < BaseProbe
        def execute(user:, **_context)
          error = request_code_completion_for(user)
          return failure(failure_text(error)) if error.present?

          success(_('Authentication with GitLab Cloud services succeeded.'))
        end

        private

        def request_code_completion_for(user)
          ::Gitlab::Llm::AiGateway::CodeSuggestionsClient.new(user).test_completion
        end

        def failure_text(error)
          format(_('Authentication with GitLab Cloud services failed: %{error}'), error: error)
        end
      end
    end
  end
end
