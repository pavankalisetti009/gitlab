# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      class ReviewMergeRequestService
        include Gitlab::Utils::StrongMemoize
        include Gitlab::InternalEventsTracking

        TIMEOUT_DURATION = 30.minutes
        # We use :duo_agent_platform as the unit primitive because this Duo Code Review feature
        # is now part of the Duo Agent Platform offering. All customers with Duo Agent Platform
        # access (via Duo Core and Duo Pro add-ons) should be able to use this feature.
        # Previously, this used :review_merge_request as a separate unit primitive with different licensing.
        #
        # Note: Duo Enterprise customers will continue using the legacy Duo Code Review for the time being.
        # More context: https://gitlab.com/gitlab-org/gitlab/-/issues/579921
        UNIT_PRIMITIVE = :duo_agent_platform

        def initialize(user:, merge_request:)
          @user = user
          @merge_request = merge_request
        end

        def execute
          progress_note = create_progress_note

          track_review_request_event

          update_review_state('review_started')

          result = start_workflow

          if result.error?
            cleanup_failed_review(progress_note)
          else
            # Schedule timeout cleanup job for 30 minutes from now in case workflow fails midway
            ::Ai::DuoWorkflows::CodeReview::TimeoutWorker.perform_in(TIMEOUT_DURATION, merge_request.id)
          end

          result
        rescue StandardError => error
          Gitlab::ErrorTracking.track_exception(error, unit_primitive: UNIT_PRIMITIVE.to_s)
          cleanup_failed_review(progress_note)
          ServiceResponse.error(message: error.message)
        end

        private

        attr_reader :user, :merge_request

        def start_workflow
          ::Ai::DuoWorkflows::CreateAndStartWorkflowService.new(
            container: merge_request.project,
            current_user: user,
            workflow_definition: ::Ai::DuoWorkflows::WorkflowDefinition['code_review/v1'],
            goal: merge_request.iid,
            source_branch: merge_request.source_branch
          ).execute
        end

        def cleanup_failed_review(progress_note)
          update_progress_note(progress_note, ::Ai::CodeReviewMessages.could_not_start_workflow_error)
          update_review_state('reviewed')
          progress_note&.destroy
        end

        def create_progress_note
          ::SystemNotes::MergeRequestsService.new(
            noteable: merge_request,
            container: merge_request.project,
            author: review_bot
          ).duo_code_review_started
        end

        def track_review_request_event
          event_name = if user.id == merge_request.author_id
                         'request_review_duo_code_review_on_mr_by_author'
                       else
                         'request_review_duo_code_review_on_mr_by_non_author'
                       end

          track_internal_event(
            event_name,
            user: user,
            project: merge_request.project,
            additional_properties: { property: merge_request.id.to_s }
          )
        end

        def update_progress_note(note, message)
          return unless note.present?

          todo_service.new_review(merge_request, review_bot)

          ::Notes::CreateService.new(
            merge_request.project,
            review_bot,
            noteable: merge_request,
            note: message
          ).execute
        end

        def update_review_state(state)
          ::MergeRequests::UpdateReviewerStateService
            .new(project: merge_request.project, current_user: review_bot)
            .execute(merge_request, state)
        end

        def review_bot
          Users::Internal.duo_code_review_bot
        end
        strong_memoize_attr :review_bot

        def todo_service
          TodoService.new
        end
        strong_memoize_attr :todo_service
      end
    end
  end
end
