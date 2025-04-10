# frozen_string_literal: true

module Llm
  class ReviewMergeRequestService < ::Llm::BaseService
    private

    def ai_action
      :review_merge_request
    end

    def perform
      progress_note = create_note(Gitlab::Llm::Anthropic::Completions::ReviewMergeRequest.review_queued_msg)

      schedule_completion_worker(progress_note_id: progress_note.id)
    end

    def valid?
      super && resource.ai_review_merge_request_allowed?(user)
    end

    def create_note(note)
      ::Notes::CreateService.new(
        resource.project,
        review_bot,
        noteable: resource,
        note: note
      ).execute
    end

    def review_bot
      Users::Internal.duo_code_review_bot
    end
  end
end
