# frozen_string_literal: true

module Llm
  class ReviewMergeRequestService < ::Llm::BaseService
    private

    def ai_action
      :review_merge_request
    end

    def perform
      progress_note = create_note

      schedule_completion_worker(progress_note_id: progress_note.id)
    end

    def valid?
      super && resource.ai_review_merge_request_allowed?(user)
    end

    def create_note
      ::SystemNotes::MergeRequestsService.new(
        noteable: resource,
        container: resource.project,
        author: review_bot
      ).duo_code_review_started
    end

    def review_bot
      Users::Internal.duo_code_review_bot
    end
  end
end
