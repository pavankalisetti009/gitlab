# frozen_string_literal: true

module Types
  module Analytics
    module AiUsage
      class AiUsageEventTypeEnum < BaseEnum
        graphql_name 'AiUsageEventType'
        description 'Type of AI usage event'

        DEPRECATION_POSTFIX = "Old data only."

        def self.declare_event(event_name, description)
          description += " #{DEPRECATION_POSTFIX}" if Gitlab::Tracking::AiTracking.deprecated_event?(event_name)

          value event_name.upcase, description: description, value: event_name
        end

        declare_event('code_suggestions_requested', "Code Suggestion was requested.")
        declare_event('code_suggestion_shown_in_ide', "Code Suggestion was shown in IDE.")
        declare_event('code_suggestion_accepted_in_ide', "Code Suggestion was accepted in IDE.")
        declare_event('code_suggestion_rejected_in_ide', "Code Suggestion was rejected in IDE.")
        declare_event('code_suggestion_direct_access_token_refresh', "Code Suggestion token was refreshed.")
        declare_event('request_duo_chat_response', "Duo Chat response was requested.")
        declare_event('troubleshoot_job', "Troubleshoot job feature was used.")
        declare_event('agent_platform_session_created', "Agent platform session was created.")
        declare_event('agent_platform_session_started', "Agent platform session was started.")
        declare_event('agent_platform_session_finished', "Agent platform session was finished.")
        declare_event('agent_platform_session_dropped', "Agent platform session was dropped.")
        declare_event('agent_platform_session_stopped', "Agent platform session was stopped.")
        declare_event('agent_platform_session_resumed', "Agent platform session was resumed.")
        declare_event('encounter_duo_code_review_error_during_review', "Duo Code Review encountered an error.")
        declare_event('find_no_issues_duo_code_review_after_review',
          "Duo Code Review found no issues after review.")
        declare_event('find_nothing_to_review_duo_code_review_on_mr',
          "Duo Code Review found nothing to review on MR.")
        declare_event('post_comment_duo_code_review_on_diff', "Duo Code Review posted a diff comment.")
        declare_event('react_thumbs_up_on_duo_code_review_comment',
          "User gave thumbs-up reaction to Duo Code Review comment.")
        declare_event('react_thumbs_down_on_duo_code_review_comment',
          "User gave thumbs-down reaction to Duo Code Review comment.")
        declare_event('request_review_duo_code_review_on_mr_by_author', "MR author requested Duo Code Review.")
        declare_event('request_review_duo_code_review_on_mr_by_non_author',
          "Non-author requested Duo Code Review on MR.")
        declare_event('excluded_files_from_duo_code_review', "Files were excluded from Duo Code Review.")
      end
    end
  end
end
