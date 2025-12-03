# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      class ProcessCommentsService
        include ::Gitlab::Utils::StrongMemoize
        include ::Ai::DuoWorkflows::CodeReview::Observability

        DRAFT_NOTES_COUNT_LIMIT = 50
        LINE_MATCH_THRESHOLD = 3
        CUSTOM_INSTRUCTIONS_REGEXP = /^According to custom instructions in .+?:/

        class Metrics
          attr_accessor :comments_with_valid_path,
            :comments_with_valid_line,
            :comments_with_custom_instructions,
            :comments_line_matched_by_content,
            :draft_notes_created,
            :total_comments

          def initialize
            @comments_with_valid_path = 0
            @comments_with_valid_line = 0
            @comments_with_custom_instructions = 0
            @comments_line_matched_by_content = 0
            @draft_notes_created = 0
            @total_comments = 0
          end
        end

        def initialize(user:, merge_request:, review_bot:, review_output:)
          @user = user
          @merge_request = merge_request
          @review_bot = review_bot
          @review_output = review_output
          @metrics = Metrics.new
        end

        def execute
          if ai_reviewable_diff_files.empty?
            track_review_merge_request_event('find_nothing_to_review_duo_code_review_on_mr')
            return error(exclusion_message_for_excluded_files + ::Ai::CodeReviewMessages.nothing_to_review)
          end

          if review_output.nil?
            track_review_merge_request_event('encounter_duo_code_review_error_during_review')
            return error(::Ai::CodeReviewMessages.invalid_review_output, create_todo: true)
          end

          draft_notes = build_draft_notes

          message =
            if draft_notes.empty?
              track_review_merge_request_event('find_no_issues_duo_code_review_after_review')
              exclusion_message_for_excluded_files + ::Ai::CodeReviewMessages.nothing_to_comment
            else
              build_summary(draft_notes)
            end

          ServiceResponse.success(
            message: message,
            payload: {
              metrics: metrics,
              draft_notes: draft_notes
            }
          )
        end

        private

        attr_reader :user, :merge_request, :review_bot, :review_output, :metrics

        def ai_reviewable_diff_files
          merge_request.ai_reviewable_diff_files.filter_map do |diff_file|
            diff_file unless excluded_files.include?(diff_file.file_path)
          end
        end
        strong_memoize_attr :ai_reviewable_diff_files

        def excluded_files
          return [] unless Feature.enabled?(:use_duo_context_exclusion, merge_request.project)

          file_paths = merge_request.diffs.diff_files.map(&:file_path)
          return [] if file_paths.empty?

          result = ::Ai::FileExclusionService.new(merge_request.project).execute(file_paths)
          return [] unless result.success?

          result.payload.filter_map { |file_result| file_result[:path] if file_result[:excluded] }
        end
        strong_memoize_attr :excluded_files

        def build_draft_notes
          mr_diff_refs = merge_request.diff_refs

          parsed_body = ::Gitlab::Llm::AiGateway::Completions::ReviewMergeRequest::ResponseBodyParser.new(review_output)
          raw_comments = parsed_body.comments
          comments = raw_comments.group_by(&:file)

          metrics.total_comments = raw_comments.count

          draft_notes = ai_reviewable_diff_files.each_with_object([]) do |diff_file, notes|
            file_comments = comments[diff_file.new_path]

            next if file_comments.blank?

            metrics.comments_with_valid_path += file_comments.count

            notes.concat(process_comments(file_comments, diff_file, mr_diff_refs))
          end.first(DRAFT_NOTES_COUNT_LIMIT)

          metrics.draft_notes_created = draft_notes.count

          draft_notes
        end

        def process_comments(comments, diff_file, diff_refs)
          comments.each_with_object([]) do |comment, draft_notes|
            diff_line = match_comment_to_diff_line(comment, diff_file.diff_lines)

            next if diff_line.blank?

            metrics.comments_with_valid_line += 1
            metrics.comments_with_custom_instructions += 1 if comment.content&.match?(CUSTOM_INSTRUCTIONS_REGEXP)

            draft_note_instance = build_draft_note_instance(comment.content, diff_file, diff_line, diff_refs)
            draft_notes << draft_note_instance if draft_note_instance
          end
        end

        def build_draft_note_instance(comment, diff_file, line, diff_refs)
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

          DraftNote.new(
            merge_request: merge_request,
            author: review_bot,
            note: comment,
            position: position
          )
        end

        def match_comment_to_diff_line(comment, diff_lines)
          diff_line = find_line_by_line_numbers(comment, diff_lines)
          from_lines = comment.from&.lines(chomp: true)

          # We only want to match if we have enough context
          if from_lines.present? && from_lines.count >= LINE_MATCH_THRESHOLD
            # We can skip the full search if the diff_line already matches the first context line
            return diff_line if diff_line&.text(prefix: false) == from_lines.first

            return find_line_by_content(from_lines, diff_lines) || diff_line
          end

          diff_line
        end

        def find_line_by_content(from_lines, diff_lines)
          # We need to ignore removed lines as the match needs to be consecutive lines.
          # Also, removed line cannot have code suggestions so we don't want to match it to removed lines.
          actual_diff_lines = diff_lines.reject(&:removed?)
          found_line = nil

          # We look for the matching lines by iterating through diff_lines and comparing entire sequences of lines
          # from <from> lines.
          actual_diff_lines.each_with_index do |start_line, start_index|
            # If we don't have enough lines left to match, we should skip the rest of the lines and exit early.
            break if start_index + from_lines.count > actual_diff_lines.count
            next unless start_line.text(prefix: false) == from_lines.first

            # Try to match the entire sequence
            sequence_matches = true

            from_lines.each_with_index do |from_line, from_index|
              actual_line = actual_diff_lines[start_index + from_index]

              # If any line doesn't match, the sequence fails
              unless actual_line.text(prefix: false) == from_line
                sequence_matches = false
                break
              end
            end

            next unless sequence_matches

            # If we found a matching sequence
            metrics.comments_line_matched_by_content += 1
            found_line = start_line
            break
          end

          # Return the found line or nil if no match
          found_line
        end

        def find_line_by_line_numbers(comment, diff_lines)
          # NOTE: LLM may return invalid line numbers sometimes so we should double check the existence of the line.
          #   Also, LLM sometimes sets old_line to the same value as new_line when it should be empty
          #   for some unknown reason. We should fallback to new_line to find a match as much as possible.

          # First try to match both old_line and new_line for precision
          exact_match = diff_lines.find do |line|
            line.old_line == comment.old_line && line.new_line == comment.new_line
          end

          return exact_match if exact_match

          # Fall back to matching only new_line
          diff_lines.find { |line| comment.new_line.present? && line.new_line == comment.new_line }
        end

        def review_note_already_exists?(position)
          existing_review_note_positions.any?(position)
        end

        def existing_review_note_positions
          merge_request
            .notes
            .diff_notes
            .authored_by(review_bot)
            .positions
            .map(&:to_h)
        end
        strong_memoize_attr :existing_review_note_positions

        def exclusion_message_for_excluded_files
          return "" if excluded_files.empty?

          track_review_merge_request_event('excluded_files_from_duo_code_review')

          context_exclusion_help_path = ::Gitlab::Utils.append_path(
            Gitlab::Routing.url_helpers.root_url,
            Gitlab::Routing.url_helpers.help_page_path('user/gitlab_duo/context.md',
              anchor: 'exclude-context-from-gitlab-duo')
          )

          <<~MESSAGE
               I do not have access to the following files due to an active context exclusion policy:
               #{excluded_files.map { |file| "* #{file}" }.join("\n")}
               [Learn more](#{context_exclusion_help_path})
          MESSAGE
        end
        strong_memoize_attr :exclusion_message_for_excluded_files

        def build_summary(draft_notes)
          response = summary_response_for(draft_notes)
          ai_message = response[:ai_message]

          if ai_message.blank? || ai_message.errors.any? || ai_message.content.blank?
            track_review_merge_request_event('encounter_duo_code_review_error_during_review')
            ::Ai::CodeReviewMessages.could_not_generate_summary_error
          else
            exclusion_message_for_excluded_files + ai_message.content
          end
        end

        def summary_response_for(draft_notes)
          action_name = :summarize_review
          message_attributes = {
            request_id: SecureRandom.uuid,
            content: action_name.to_s.humanize,
            role: ::Gitlab::Llm::AiMessage::ROLE_USER,
            ai_action: action_name,
            user: user,
            context: ::Gitlab::Llm::AiMessageContext.new(resource: merge_request)
          }
          summary_prompt_message = ::Gitlab::Llm::AiMessage.for(action: action_name).new(message_attributes)
          summarize_review = Gitlab::Llm::AiGateway::Completions::SummarizeReview.new(
            summary_prompt_message,
            nil,
            { draft_notes: draft_notes }
          )

          summarize_review.execute
        end
      end
    end
  end
end
