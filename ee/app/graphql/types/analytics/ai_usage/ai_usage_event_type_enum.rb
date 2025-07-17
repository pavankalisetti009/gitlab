# frozen_string_literal: true

module Types
  module Analytics
    module AiUsage
      class AiUsageEventTypeEnum < BaseEnum
        graphql_name 'AiUsageEventType'
        description 'Type of AI usage event'

        value "CODE_SUGGESTION_REQUESTED",
          description: "Code Suggestion was requested (old data only).",
          value: 'code_suggestion_requested'
        value "CODE_SUGGESTION_SHOWN_IN_IDE",
          description: "Code Suggestion was shown in IDE.",
          value: 'code_suggestion_shown_in_ide'
        value "CODE_SUGGESTION_ACCEPTED_IN_IDE",
          description: "Code Suggestion was accepted in IDE.",
          value: 'code_suggestion_accepted_in_ide'
        value "CODE_SUGGESTION_REJECTED_IN_IDE",
          description: "Code Suggestion was rejected in IDE.",
          value: 'code_suggestion_rejected_in_ide'
        value "CODE_SUGGESTION_DIRECT_ACCESS_TOKEN_REFRESH",
          description: "Code Suggestion token was refreshed (old data only).",
          value: 'code_suggestion_direct_access_token_refresh'
        value "REQUEST_DUO_CHAT_RESPONSE",
          description: "Duo Chat response was requested.",
          value: 'request_duo_chat_response'
        value "TROUBLESHOOT_JOB",
          description: "Troubleshoot job feature was used.",
          value: 'troubleshoot_job'
      end
    end
  end
end
