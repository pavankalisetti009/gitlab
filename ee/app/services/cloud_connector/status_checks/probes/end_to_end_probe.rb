# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      # Performs a real request using the current user to verify that AI features work.
      class EndToEndProbe < BaseProbe
        def execute(user:, **_context)
          error = request_code_completion_for(user)
          return failure(format(_('Code completion test failed: %{error}'), error: error)) if error.present?

          success(_('Code completion test was successful'))
        end

        private

        def request_code_completion_for(user)
          ::Gitlab::Llm::AiGateway::CodeSuggestionsClient.new(user).test_completion
        end
      end
    end
  end
end
