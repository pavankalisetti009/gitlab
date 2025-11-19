# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      class CreateCommentsService
        include ::Gitlab::Utils::StrongMemoize
        include ::Ai::DuoWorkflows::CodeReview::Observability

        ValidationError = Class.new(StandardError)

        def initialize(user:, merge_request:, review_output:)
          @user = user
          @merge_request = merge_request
          @review_output = review_output
        end

        def execute
          # Resource can be empty when permission check fails in Llm::Internal::CompletionService.
          # This would most likely happen when the parent group has SAML SSO enabled and the Duo Code Review is
          # triggered via an API call. It's a known limitation of SAML SSO currently.
          raise ValidationError, ::Ai::CodeReviewMessages.merge_request_not_found_error unless merge_request

          # Progress note creation may fail, so we halt execution and report the error.
          raise ValidationError, ::Ai::CodeReviewMessages.progress_note_not_found_error unless progress_note

          processed_comments = ProcessCommentsService.new(
            user: user,
            merge_request: merge_request,
            review_output: review_output,
            review_bot: review_bot
          ).execute

          metrics = processed_comments.payload[:metrics]
          message = processed_comments.message

          log_metrics(metrics) if metrics

          if processed_comments.error?
            create_todo = processed_comments.payload.fetch(:create_todo, false)
            update_progress_note(message, with_todo: create_todo)
            return error(message)
          end

          draft_notes = Array(processed_comments.payload[:draft_notes])

          if draft_notes.empty?
            update_progress_note(message, with_todo: true)
            track_review_merge_request_event('find_no_issues_duo_code_review_after_review')
          else
            publish_draft_notes(draft_notes, message)
          end

          ServiceResponse.success
        rescue ValidationError => error
          track_review_merge_request_exception(error)
          error(error.message)
        rescue StandardError => error
          track_review_merge_request_exception(error)
          track_review_merge_request_event('encounter_duo_code_review_error_during_review')
          message = ::Ai::CodeReviewMessages.generic_error
          update_progress_note(message, with_todo: true)
          error(message)
        ensure
          update_review_state('reviewed')
          progress_note&.destroy
        end

        private

        attr_reader :user, :merge_request, :review_output

        def review_bot
          Users::Internal.duo_code_review_bot
        end
        strong_memoize_attr :review_bot

        def progress_note
          return unless merge_request

          find_progress_note || create_progress_note
        rescue StandardError => error
          track_review_merge_request_exception(error)
          nil
        end
        strong_memoize_attr :progress_note

        def find_progress_note
          merge_request.duo_code_review_progress_note
        end

        def create_progress_note
          ::SystemNotes::MergeRequestsService.new(
            noteable: merge_request,
            container: merge_request.project,
            author: review_bot
          ).duo_code_review_started
        end

        def update_progress_note(note, with_todo: false)
          return unless progress_note

          TodoService.new.new_review(merge_request, review_bot) if with_todo

          ::Notes::CreateService.new(
            merge_request.project,
            review_bot,
            noteable: merge_request,
            note: note
          ).execute
        end

        def update_review_state(state)
          return unless merge_request

          ::MergeRequests::UpdateReviewerStateService.new(
            project: merge_request.project,
            current_user: review_bot
          ).execute(merge_request, state)
        end

        def publish_draft_notes(draft_notes, summary)
          return unless Ability.allowed?(user, :create_note, merge_request)
          return if draft_notes.empty?

          DraftNote.bulk_insert_and_keep_commits!(draft_notes, batch_size: 20)

          update_progress_note(summary)

          track_review_merge_request_event(
            'post_comment_duo_code_review_on_diff',
            additional_properties: {
              value: draft_notes.size
            }
          )

          # We set `executing_user` as the user who executed the duo code
          # review action as we only want to publish duo code review bot's review
          # if the executing user is allowed to create notes on the MR.
          DraftNotes::PublishService
            .new(
              merge_request,
              review_bot
            ).execute(executing_user: user)
        end

        def log_metrics(metrics)
          return unless Feature.enabled?(:duo_code_review_response_logging, user)

          log_review_merge_request_event(
            message: "LLM response comments metrics",
            event: "review_merge_request_llm_response_comments",
            merge_request_id: merge_request.id,
            total_comments: metrics.total_comments,
            comments_with_valid_path: metrics.comments_with_valid_path,
            comments_with_valid_line: metrics.comments_with_valid_line,
            comments_with_custom_instructions: metrics.comments_with_custom_instructions,
            comments_line_matched_by_content: metrics.comments_line_matched_by_content,
            draft_notes_created: metrics.draft_notes_created
          )
        end
      end
    end
  end
end
