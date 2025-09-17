# frozen_string_literal: true

module Gitlab
  module Tracking
    # Class for tracking AI usage events.
    # @see doc/development/ai_features/usage_tracking.md for documentation
    module AiTracking
      extend AiUsageEventsRegistryDsl

      register do
        deprecated_events(code_suggestions_requested: 1) # old data

        events(
          code_suggestion_shown_in_ide: 2,
          code_suggestion_accepted_in_ide: 3,
          code_suggestion_rejected_in_ide: 4
        ) do |context|
          context.slice(*%w[unique_tracking_id suggestion_size language branch_name
            ide_name ide_vendor ide_version
            extension_name extension_version language_server_version
            model_name model_engine])
        end

        deprecated_events(code_suggestion_direct_access_token_refresh: 5) # old data

        events(request_duo_chat_response: 6)

        events(troubleshoot_job: 7) do |context|
          {
            job_id: context['job'].id,
            project_id: context['job'].project_id,
            pipeline_id: context['job'].pipeline&.id,
            merge_request_id: context['job'].pipeline&.merge_request_id
          }
        end

        events(agent_platform_session_created: 8, agent_platform_session_started: 9) do |context|
          {
            project_id: context['project']&.id,
            session_id: context['value'],
            flow_type: context['label'],
            environment: context['property']
          }
        end

        events(
          encounter_duo_code_review_error_during_review: 10,
          find_no_issues_duo_code_review_after_review: 11,
          find_nothing_to_review_duo_code_review_on_mr: 12,
          post_comment_duo_code_review_on_diff: 13,
          react_thumbs_up_on_duo_code_review_comment: 14,
          react_thumbs_down_on_duo_code_review_comment: 15,
          request_review_duo_code_review_on_mr_by_author: 16,
          request_review_duo_code_review_on_mr_by_non_author: 17,
          excluded_files_from_duo_code_review: 18
        )
      end

      class << self
        def track_event(event_name, **context_hash)
          tracked = UnifiedApproach.track_event(event_name, **context_hash)

          track_user_activity(context_hash[:user]) if tracked
        end

        def track_user_activity(user)
          ::Ai::UserMetrics.refresh_last_activity_on(user)
        end
      end
    end
  end
end
