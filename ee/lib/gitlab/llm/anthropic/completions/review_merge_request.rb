# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Completions
        class ReviewMergeRequest < Gitlab::Llm::Completions::Base
          include Gitlab::Utils::StrongMemoize

          DRAFT_NOTES_COUNT_LIMIT = 50
          PRIORITY_THRESHOLD = 3

          class << self
            def review_queued_msg
              s_("DuoCodeReview|I've received your Duo Code Review request, and will review your code shortly.")
            end

            def resource_not_found_msg
              s_("DuoCodeReview|Can't access the merge request. When SAML single sign-on is enabled " \
                "on a group or its parent, Duo Code Reviews can't be requested from the API. Request a " \
                "review from the GitLab UI instead.")
            end

            def nothing_to_review_msg
              s_("DuoCodeReview|:wave: There's nothing for me to review.")
            end

            def no_comment_msg
              s_("DuoCodeReview|I finished my review and found nothing to comment on. Nice work! :tada:")
            end

            def error_msg
              s_("DuoCodeReview|I have encountered some problems while I was reviewing. Please try again later.")
            end
          end

          def execute
            # Progress note may not exist for existing jobs so we create one if we can
            @progress_note = find_progress_note || create_progress_note

            unless progress_note.present?
              Gitlab::ErrorTracking.track_exception(
                StandardError.new("Unable to perform Duo Code Review: progress_note and resource not found")
              )
              return # Cannot proceed without both progress note and resource
            end

            # Resource can be empty when permission check fails in Llm::Internal::CompletionService.
            # This would most likely happen when the parent group has SAML SSO enabled and the Duo Code Review is
            #   triggered via an API call. It's a known limitation of SAML SSO currently.
            return update_progress_note(self.class.resource_not_found_msg) unless resource.present?

            update_review_state('review_started')

            if merge_request.ai_reviewable_diff_files.blank?
              update_progress_note(self.class.nothing_to_review_msg)
            else
              perform_review
            end

          rescue StandardError => error
            Gitlab::ErrorTracking.track_exception(error)

            update_progress_note(self.class.error_msg, with_todo: true) if progress_note.present?

          ensure
            update_review_state('reviewed') if merge_request.present?

            @progress_note&.destroy if duo_code_review_system_note_enabled?
          end

          private

          attr_reader :progress_note

          def perform_review
            # Initialize ivar that will be populated as AI review diff hunks
            @draft_notes_by_priority = []

            diff_files = merge_request.ai_reviewable_diff_files

            if diff_files.blank?
              update_progress_note(self.class.nothing_to_review_msg)

              return
            end

            mr_diff_refs = merge_request.diff_refs

            if Feature.enabled?(:duo_code_review_multi_file, user)
              process_all_files_together(diff_files, mr_diff_refs)
            else
              process_files_individually(diff_files, mr_diff_refs)
            end

            if @draft_notes_by_priority.empty?
              update_progress_note(self.class.no_comment_msg, with_todo: true)
            else
              publish_draft_notes
            end
          end

          def process_all_files_together(diff_files, mr_diff_refs)
            diffs_and_paths = diff_files.each_with_object({}) do |diff_file, result|
              result[diff_file.new_path] = diff_file.raw_diff
            end

            review_prompt = generate_review_prompt(diffs_and_paths)
            return unless review_prompt.present?

            response = review_response_for(review_prompt)
            return if note_not_required?(response)

            parsed_body = ResponseBodyParser.new(response.response_body)
            comments_by_file = parsed_body.comments.group_by(&:file)

            diff_files.each do |diff_file|
              file_comments = comments_by_file[diff_file.new_path]
              next if file_comments.blank?

              process_comments(file_comments, diff_file, mr_diff_refs)
            end
          end

          def process_files_individually(diff_files, mr_diff_refs)
            diff_files.each do |diff_file|
              single_file_diff = { diff_file.new_path => diff_file.raw_diff }

              review_prompt = generate_review_prompt(single_file_diff)
              next unless review_prompt.present?

              response = review_response_for(review_prompt)
              next if note_not_required?(response)

              parsed_body = ResponseBodyParser.new(response.response_body)
              file_comments = parsed_body.comments.select { |comment| comment.file == diff_file.new_path }

              process_comments(file_comments, diff_file, mr_diff_refs)
            end
          end

          def process_comments(comments, diff_file, diff_refs)
            comments.each do |comment|
              # NOTE: LLM may return invalid line numbers sometimes so we should double check the existence of the line.
              line = diff_file.diff_lines.find do |line|
                line.old_line == comment.old_line && line.new_line == comment.new_line
              end

              next unless line.present?

              draft_note_params = build_draft_note_params(comment.content, diff_file, line, diff_refs)
              next unless draft_note_params.present?

              @draft_notes_by_priority << [comment.priority, draft_note_params]
            end
          end

          def ai_client
            @ai_client ||= ::Gitlab::Llm::Anthropic::Client.new(
              user,
              unit_primitive: "review_merge_request",
              tracking_context: tracking_context
            )
          end

          def review_bot
            Users::Internal.duo_code_review_bot
          end

          def merge_request
            # Fallback is needed to handle review state change as much as possible
            resource || progress_note&.noteable
          end

          def generate_review_prompt(diffs_and_paths)
            ai_prompt_class.new(
              mr_title: merge_request.title,
              mr_description: merge_request.description,
              diffs_and_paths: diffs_and_paths,
              user: user
            ).to_prompt
          end

          def review_response_for(prompt)
            response = ai_client.messages_complete(**prompt)

            log_llm_response_metrics(response)

            ::Gitlab::Llm::Anthropic::ResponseModifiers::ReviewMergeRequest.new(response)
          end

          def summary_response_for(draft_notes)
            summary_prompt = Gitlab::Llm::Templates::SummarizeReview.new(draft_notes).to_prompt

            response = ai_client.messages_complete(**summary_prompt)

            ::Gitlab::Llm::Anthropic::ResponseModifiers::ReviewMergeRequest.new(response)
          end

          def log_llm_response_metrics(response)
            return unless Feature.enabled?(:duo_code_review_response_logging, user)

            Gitlab::AppLogger.info(
              message: "LLM response metrics",
              event: "review_merge_request_llm_response_received",
              merge_request_id: merge_request&.id,
              response_id: response&.[]("id"),
              stop_reason: response&.[]("stop_reason"),
              input_tokens: response&.dig("usage", "input_tokens"),
              output_tokens: response&.dig("usage", "output_tokens")
            )
          end

          def note_not_required?(response_modifier)
            response_modifier.errors.any? || response_modifier.response_body.blank?
          end

          def build_draft_note_params(comment, diff_file, line, diff_refs)
            position = {
              base_sha: diff_refs.base_sha,
              start_sha: diff_refs.start_sha,
              head_sha: diff_refs.head_sha,
              old_path: diff_file.old_path,
              new_path: diff_file.new_path,
              position_type: 'text',
              old_line: line.old_line,
              new_line: line.new_line,
              ignore_whitespace_change: false
            }

            return if review_note_already_exists?(position)

            {
              merge_request: merge_request,
              author: review_bot,
              note: comment,
              position: position
            }
          end

          def review_note_already_exists?(position)
            merge_request
              .notes
              .diff_notes
              .authored_by(review_bot)
              .positions
              .any? { |pos| pos.to_h >= position }
          end

          def create_progress_note
            return unless merge_request.present?

            note = if duo_code_review_system_note_enabled?
                     s_("DuoCodeReview|is reviewing your merge request and will let you know when it's finished")
                   else
                     self.class.review_queued_msg
                   end

            ::Notes::CreateService.new(
              merge_request.project,
              review_bot,
              noteable: merge_request,
              note: note,
              system: duo_code_review_system_note_enabled?
            ).execute
          end

          def update_progress_note(note, with_todo: false)
            todo_service.new_review(merge_request, review_bot) if with_todo

            if duo_code_review_system_note_enabled?
              ::Notes::CreateService.new(
                merge_request.project,
                review_bot,
                noteable: merge_request,
                note: note
              ).execute
            else
              Notes::UpdateService.new(
                progress_note.project,
                review_bot,
                note: note
              ).execute(progress_note)
            end
          end

          def find_progress_note
            Note.find_by_id(options[:progress_note_id])
          end

          def summary_note(draft_notes)
            response = summary_response_for(draft_notes)

            if response.errors.any? || response.response_body.blank?
              self.class.error_msg
            else
              response.response_body
            end
          end

          # rubocop: disable CodeReuse/ActiveRecord -- NOT a ActiveRecord object
          def trimmed_draft_note_params
            # Filter out lower priority comments (< 3) and take only a limited
            # number of reviews to minimize the review volume
            @draft_notes_by_priority
              .select { |note| note.first >= PRIORITY_THRESHOLD }
              .take(DRAFT_NOTES_COUNT_LIMIT)
              .map(&:last)
          end
          # rubocop: enable CodeReuse/ActiveRecord

          def publish_draft_notes
            return unless Ability.allowed?(user, :create_note, merge_request)

            draft_notes = trimmed_draft_note_params.map do |params|
              DraftNote.new(params)
            end

            if draft_notes.empty?
              update_progress_note(self.class.no_comment_msg, with_todo: true)

              return
            end

            DraftNote.bulk_insert!(draft_notes, batch_size: 20)

            update_progress_note(summary_note(draft_notes))

            # We set `executing_user` as the user who executed the duo code
            # review action as we only want to publish duo code review bot's review
            # if the executing user is allowed to create notes on the MR.
            DraftNotes::PublishService
              .new(
                merge_request,
                review_bot
              ).execute(executing_user: user)
          end

          def update_review_state_service
            ::MergeRequests::UpdateReviewerStateService
              .new(project: merge_request.project, current_user: review_bot)
          end
          strong_memoize_attr :update_review_state_service

          def update_review_state(state)
            update_review_state_service.execute(merge_request, state)
          end

          def duo_code_review_system_note_enabled?
            ::Feature.enabled?(:duo_code_review_system_note, merge_request&.project)
          end

          def todo_service
            TodoService.new
          end
          strong_memoize_attr :todo_service
        end
      end
    end
  end
end
