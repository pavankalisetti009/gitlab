# frozen_string_literal: true

module MergeRequests
  class DuoCodeReviewChatWorker # rubocop:disable Scalability/IdempotentWorker -- Running worker twice will create duplicate notes
    include ApplicationWorker

    feature_category :code_review_workflow
    urgency :low
    data_consistency :sticky
    worker_has_external_dependencies!
    deduplicate :until_executed
    sidekiq_options retry: 3

    def perform(note_id)
      note = Note.find_by_id(note_id)

      return unless note
      return unless note.duo_bot_mentioned?

      prompt_message = prepare_prompt_message(note)
      response = execute_chat_request(prompt_message, note)
      create_note_from(note, response)
    end

    private

    def prepare_prompt_message(note)
      author = note.author

      # Reset chat to not mix context
      prompt_message = save_prompt_message(author, ::Gitlab::Llm::AiMessage::ROLE_USER, note, '/reset')

      note.discussion.notes.each do |note|
        # We skip notes that are not mentioning the bot as we don't need it included
        # in the context we send with our chat request.
        next unless note.duo_bot_mentioned? || note.authored_by_duo_bot?

        role =
          if note.authored_by_duo_bot?
            ::Gitlab::Llm::AiMessage::ROLE_ASSISTANT
          else
            ::Gitlab::Llm::AiMessage::ROLE_USER
          end

        prompt_message = save_prompt_message(author, role, note, note.note)
      end

      prompt_message
    end

    def save_prompt_message(user, role, resource, content)
      prompt_message = ::Gitlab::Llm::ChatMessage
        .new(
          ai_action: 'chat',
          user: user,
          content: content,
          role: role,
          context: ::Gitlab::Llm::AiMessageContext.new(resource: resource)
        )

      prompt_message.save!
      prompt_message
    end

    def execute_chat_request(prompt_message, note)
      ::Gitlab::Llm::Completions::Chat
        .new(
          prompt_message,
          nil,
          additional_context: {
            id: note.latest_diff_file_path,
            category: 'merge_request',
            content: note.raw_truncated_diff_lines
          }
        )
        .execute
    end

    def create_note_from(note, response)
      return if response.response_body.blank?

      merge_request = note.noteable

      ::Notes::CreateService.new(
        merge_request.project,
        ::Users::Internal.duo_code_review_bot,
        noteable: merge_request,
        note: response.response_body,
        in_reply_to_discussion_id: note.discussion_id,
        type: 'DiffNote'
      ).execute
    end
  end
end
