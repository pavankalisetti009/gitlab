# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Completions
        class ReviewMergeRequest < Gitlab::Llm::Completions::Base
          include Gitlab::Utils::StrongMemoize
          include Gitlab::InternalEventsTracking

          DRAFT_NOTES_COUNT_LIMIT = 50
          PRIORITY_THRESHOLD = 3
          UNIT_PRIMITIVE = 'review_merge_request'
          COMMENT_METRICS = %i[
            total_comments
            p1_comments
            p2_comments
            p3_comments
            comments_with_valid_path
            comments_with_valid_line
            created_draft_notes
          ].freeze

          class << self
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
                StandardError.new("Unable to perform Duo Code Review: progress_note and resource not found"),
                unit_primitive: UNIT_PRIMITIVE
              )
              return # Cannot proceed without both progress note and resource
            end

            # Resource can be empty when permission check fails in Llm::Internal::CompletionService.
            # This would most likely happen when the parent group has SAML SSO enabled and the Duo Code Review is
            #   triggered via an API call. It's a known limitation of SAML SSO currently.
            return update_progress_note(self.class.resource_not_found_msg) unless resource.present?

            update_review_state('review_started')

            if merge_request.ai_reviewable_diff_files.blank?
              log_duo_code_review_internal_event('find_nothing_to_review_duo_code_review_on_mr')

              update_progress_note(self.class.nothing_to_review_msg)
            else
              perform_review
            end

          rescue StandardError => error
            Gitlab::ErrorTracking.track_exception(error, unit_primitive: UNIT_PRIMITIVE)

            log_duo_code_review_internal_event('encounter_duo_code_review_error_during_review')

            update_progress_note(self.class.error_msg, with_todo: true) if progress_note.present?

          ensure
            update_review_state('reviewed') if merge_request.present?

            @progress_note&.destroy
          end

          private

          attr_reader :progress_note

          def perform_review
            # Initialize ivar that will be populated as AI review diff hunks
            @draft_notes_by_priority = []
            @comment_metrics = COMMENT_METRICS.index_with(0)

            diff_files = merge_request.ai_reviewable_diff_files

            if diff_files.blank?
              log_duo_code_review_internal_event('find_nothing_to_review_duo_code_review_on_mr')

              update_progress_note(self.class.nothing_to_review_msg)

              return
            end

            mr_diff_refs = merge_request.diff_refs

            process_files(diff_files, mr_diff_refs)

            if @draft_notes_by_priority.empty?
              update_progress_note(review_summary, with_todo: true)

              log_duo_code_review_internal_event('find_no_issues_duo_code_review_after_review')
            else
              publish_draft_notes
            end

            log_comment_metrics
          end

          def process_files(diff_files, mr_diff_refs)
            diffs_and_paths = {}
            files_content = {}

            diff_files.each do |diff_file|
              diffs_and_paths[diff_file.new_path] = diff_file.raw_diff
              # Skip newly added files and deleted files since their full content is already in the diff
              next if diff_file.new_file? || diff_file.deleted_file?
              next unless include_file_content?

              content = diff_file.old_blob&.data
              files_content[diff_file.new_path] = content if content.present?
            end

            response = process_review_with_retry(diffs_and_paths, files_content)
            return if note_not_required?(response)

            parsed_body = ResponseBodyParser.new(response.response_body)
            comments = parsed_body.comments
            @review_description = parsed_body.review_description

            @comment_metrics[:total_comments] = comments.count
            comments.each do |comment|
              @comment_metrics[:"p#{comment.priority}_comments"] += 1 if comment.priority.in?(1..3)
            end

            comments_by_file = comments.group_by(&:file)
            diff_files.each do |diff_file|
              file_comments = comments_by_file[diff_file.new_path]
              next if file_comments.blank?

              @comment_metrics[:comments_with_valid_path] += file_comments.count

              process_comments(file_comments, diff_file, mr_diff_refs)
            end
          end

          def process_review_with_retry(diffs_and_paths, files_content)
            # First try with file content (if any)
            if files_content.present?
              prompt = generate_review_prompt(diffs_and_paths, files_content)
              return unless prompt.present?

              response = review_response_for(prompt)
              unless response.errors.any?
                log_llm_response_metrics(response.ai_response)
                return response
              end

              if duo_code_review_logging_enabled?
                Gitlab::AppLogger.info(
                  message: "Review request failed with files content, retrying without file content",
                  event: "review_merge_request_retry_without_content",
                  unit_primitive: UNIT_PRIMITIVE,
                  merge_request_id: merge_request&.id,
                  error: response.errors
                )
              end
            end

            # Retry without file content on failure or if no file content was provided
            prompt = generate_review_prompt(diffs_and_paths, {})

            response = review_response_for(prompt)
            log_llm_response_metrics(response.ai_response)
            response
          end

          def include_file_content?
            Feature.enabled?(:duo_code_review_full_file, user)
          end
          strong_memoize_attr :include_file_content?

          def duo_code_review_logging_enabled?
            Feature.enabled?(:duo_code_review_response_logging, user)
          end
          strong_memoize_attr :duo_code_review_logging_enabled?

          def process_comments(comments, diff_file, diff_refs)
            comments.each do |comment|
              line = match_comment_to_diff_line(comment, diff_file.diff_lines)

              next unless line.present?

              @comment_metrics[:comments_with_valid_line] += 1

              draft_note_params = build_draft_note_params(comment.content, diff_file, line, diff_refs)
              next unless draft_note_params.present?

              @draft_notes_by_priority << [comment.priority, draft_note_params]
            end
          end

          def match_comment_to_diff_line(comment, diff_lines)
            # NOTE: LLM may return invalid line numbers sometimes so we should double check the existence of the line.
            #   Also, LLM sometimes sets old_line to the same value as new_line when it should be empty
            #   for some unknown reason. We should fallback to new_line to find a match as much as possible.
            #

            # First try to match both old_line and new_line for precision
            exact_match = diff_lines.find do |line|
              line.old_line == comment.old_line && line.new_line == comment.new_line
            end

            return exact_match if exact_match

            # Fall back to matching only new_line
            diff_lines.find { |line| comment.new_line.present? && line.new_line == comment.new_line }
          end

          def ai_client
            @ai_client ||= ::Gitlab::Llm::Anthropic::Client.new(
              user,
              unit_primitive: UNIT_PRIMITIVE,
              tracking_context: tracking_context
            )
          end

          def review_bot
            Users::Internal.duo_code_review_bot
          end
          strong_memoize_attr :review_bot

          def merge_request
            # Fallback is needed to handle review state change as much as possible
            resource || progress_note&.noteable
          end

          def generate_review_prompt(diffs_and_paths, files_content)
            ai_prompt_class.new(
              mr_title: merge_request.title,
              mr_description: merge_request.description,
              diffs_and_paths: diffs_and_paths,
              files_content: files_content,
              user: user
            ).to_prompt
          end

          def review_response_for(prompt)
            response = ai_client.messages_complete(**prompt)

            ::Gitlab::Llm::Anthropic::ResponseModifiers::ReviewMergeRequest.new(response)
          end

          def summary_response_for(draft_notes)
            summary_prompt = Gitlab::Llm::Templates::SummarizeReview.new(draft_notes).to_prompt

            response = ai_client.messages_complete(**summary_prompt)

            ::Gitlab::Llm::Anthropic::ResponseModifiers::ReviewMergeRequest.new(response)
          end

          def log_llm_response_metrics(response)
            return unless duo_code_review_logging_enabled?

            input_tokens = response&.dig("usage", "input_tokens")
            output_tokens = response&.dig("usage", "output_tokens")
            total_tokens = input_tokens.to_i + output_tokens.to_i

            Gitlab::AppLogger.info(
              message: "LLM response metrics",
              event: "review_merge_request_llm_response_received",
              unit_primitive: UNIT_PRIMITIVE,
              merge_request_id: merge_request&.id,
              response_id: response&.[]("id"),
              stop_reason: response&.[]("stop_reason"),
              input_tokens: input_tokens,
              output_tokens: output_tokens,
              total_tokens: total_tokens,
              error_message: response&.dig("error", "message")
            )
          end

          def log_comment_metrics
            return unless duo_code_review_logging_enabled?

            Gitlab::AppLogger.info(
              message: "LLM response comments metrics",
              event: "review_merge_request_llm_response_comments",
              unit_primitive: UNIT_PRIMITIVE,
              merge_request_id: merge_request&.id,
              total_comments: @comment_metrics[:total_comments],
              p1_comments: @comment_metrics[:p1_comments],
              p2_comments: @comment_metrics[:p2_comments],
              p3_comments: @comment_metrics[:p3_comments],
              comments_with_valid_path: @comment_metrics[:comments_with_valid_path],
              comments_with_valid_line: @comment_metrics[:comments_with_valid_line],
              created_draft_notes: @comment_metrics[:created_draft_notes]
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

            ::SystemNotes::MergeRequestsService.new(
              noteable: merge_request,
              container: merge_request.project,
              author: review_bot
            ).duo_code_review_started
          end

          def update_progress_note(note, with_todo: false)
            todo_service.new_review(merge_request, review_bot) if with_todo

            ::Notes::CreateService.new(
              merge_request.project,
              review_bot,
              noteable: merge_request,
              note: note
            ).execute
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
            notes = @draft_notes_by_priority

            unless Feature.enabled?(:duo_code_review_show_all_comments, user)
              # Filter out lower priority comments (< 3) and take only a limited
              # number of reviews to minimize the review volume
              notes = notes.select { |note| note.first >= PRIORITY_THRESHOLD }
            end

            notes.take(DRAFT_NOTES_COUNT_LIMIT).map(&:last)
          end
          # rubocop: enable CodeReuse/ActiveRecord

          def review_summary
            [self.class.no_comment_msg, @review_description].compact.join("\n\n")
          end

          def publish_draft_notes
            return unless Ability.allowed?(user, :create_note, merge_request)

            draft_notes = trimmed_draft_note_params.map do |params|
              DraftNote.new(params)
            end

            if draft_notes.empty?
              update_progress_note(review_summary, with_todo: true)

              log_duo_code_review_internal_event('find_no_issues_duo_code_review_after_review')

              return
            end

            DraftNote.bulk_insert!(draft_notes, batch_size: 20)

            @comment_metrics[:created_draft_notes] = draft_notes.count

            update_progress_note(summary_note(draft_notes))

            log_duo_code_review_internal_event(
              'post_comment_duo_code_review_on_diff',
              additional_properties: { value: draft_notes.size }
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

          def update_review_state_service
            ::MergeRequests::UpdateReviewerStateService
              .new(project: merge_request.project, current_user: review_bot)
          end
          strong_memoize_attr :update_review_state_service

          def update_review_state(state)
            update_review_state_service.execute(merge_request, state)
          end

          def log_duo_code_review_internal_event(event_name, **additional_properties)
            track_internal_event(
              event_name,
              user: user,
              project: merge_request.project,
              **additional_properties
            )
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
