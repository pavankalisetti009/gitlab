# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Completions
        class ReviewMergeRequest < Gitlab::Llm::Completions::Base
          DRAFT_NOTES_COUNT_LIMIT = 50
          OUTPUT_TOKEN_LIMIT = 8000
          PRIORITY_THRESHOLD = 3

          def execute
            create_progress_note

            # Initialize ivar that will be populated as AI review diff hunks
            @draft_notes_by_priority = []
            mr_diff_refs = merge_request.diff_refs

            merge_request.ai_reviewable_diff_files.each do |diff_file|
              # NOTE: perhaps we should fall back to hunk when diff_file is too large?
              # I'm just ignoring this for now
              review_prompt = generate_review_prompt(diff_file, {})

              next unless review_prompt.present?

              response = review_response_for(user, review_prompt)

              build_draft_notes(response, diff_file, mr_diff_refs)
            end

            publish_draft_notes
          end

          private

          def ai_client(user, unit_primitive)
            ::Gitlab::Llm::Anthropic::Client.new(
              user,
              unit_primitive: unit_primitive,
              tracking_context: tracking_context
            )
          end

          def review_bot
            Users::Internal.duo_code_review_bot
          end

          def merge_request
            resource
          end

          def generate_review_prompt(diff_file, hunk)
            ai_prompt_class.new(diff_file.new_path, diff_file.raw_diff, hunk[:text]).to_prompt
          end

          def review_response_for(user, prompt)
            response = ai_client(user, "review_merge_request").messages_complete(**prompt)

            ::Gitlab::Llm::Anthropic::ResponseModifiers::ReviewMergeRequest.new(response)
          end

          def summary_response_for(user, draft_notes)
            summary_prompt = Gitlab::Llm::Templates::SummarizeReview.new(draft_notes).to_prompt

            response = ai_client(user, "summarize_review").messages_complete(**summary_prompt)

            ::Gitlab::Llm::Anthropic::ResponseModifiers::ReviewMergeRequest.new(response)
          end

          def note_not_required?(response_modifier)
            response_modifier.errors.any? || response_modifier.response_body.blank?
          end

          def build_draft_notes(response_modifier, diff_file, diff_refs)
            return if note_not_required?(response_modifier)

            response = Nokogiri::XML.parse(response_modifier.response_body)
            response.css('review comment').each do |comment|
              next unless comment['line'].present? && comment['priority'].present?

              # Occasionally LLM gets the line number wrong and it seems that
              # it's be safer for us to try to match them as much as we can.
              new_line = comment['line'].to_i
              line = diff_file.diff_lines.find { |line| line.new_line == new_line }
              next unless line.present?

              draft_note_params = build_draft_note_params(comment.content, diff_file, line, diff_refs)
              next unless draft_note_params.present?

              @draft_notes_by_priority << [
                comment['priority'].to_i,
                draft_note_params
              ]
            end
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
            @progress_note = Notes::CreateService.new(
              merge_request.project,
              review_bot,
              noteable: merge_request,
              note: s_("DuoCodeReview|Hey :wave: I'm starting to review your merge request and " \
                "I will let you know when I'm finished.")
            ).execute
          end

          def update_progress_note_with_review_summary(draft_notes)
            Notes::UpdateService.new(
              merge_request.project,
              review_bot,
              note: summary_note(draft_notes)
            ).execute(@progress_note)
          end

          def summary_note(draft_notes)
            if draft_notes.blank?
              s_("DuoCodeReview|I finished my review and found nothing to comment on. Nice work! :tada:")
            else
              response = summary_response_for(user, draft_notes)

              if response.errors.any? || response.response_body.blank?
                s_("DuoCodeReview|I have encountered some issues while I was reviewing. Please try again later.")
              else
                response.response_body
              end
            end
          end

          # rubocop: disable CodeReuse/ActiveRecord -- NOT a ActiveRecord object
          def sorted_and_trimmed_draft_note_params
            # Filter out lower priority comments (< 3) and take only a limited
            # number of reviews to minimize the review volume
            @draft_notes_by_priority
              .select { |note| note.first >= PRIORITY_THRESHOLD }
              .take(DRAFT_NOTES_COUNT_LIMIT)
              .map(&:last)
          end
          # rubocop: enable CodeReuse/ActiveRecord

          def publish_draft_notes
            if @draft_notes_by_priority.empty?
              update_progress_note_with_review_summary([])

              return
            end

            return unless Ability.allowed?(user, :create_note, merge_request)

            draft_notes = sorted_and_trimmed_draft_note_params.map do |params|
              DraftNote.new(params)
            end

            DraftNote.bulk_insert!(draft_notes, batch_size: 20)

            # We set `executing_user` as the user who executed the duo code
            # review action as we only want to publish duo code review bot's review
            # if the executing user is allowed to create notes on the MR.
            DraftNotes::PublishService
              .new(
                merge_request,
                review_bot
              ).execute(executing_user: user)

            update_progress_note_with_review_summary(draft_notes)
          end
        end
      end
    end
  end
end
