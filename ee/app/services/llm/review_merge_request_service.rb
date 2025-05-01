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
      note = if duo_code_review_system_note_enabled?
               s_("DuoCodeReview|is reviewing your merge request and will let you know when it's finished")
             else
               Gitlab::Llm::Anthropic::Completions::ReviewMergeRequest.review_queued_msg
             end

      ::Notes::CreateService.new(
        resource.project,
        review_bot,
        noteable: resource,
        note: note,
        system: duo_code_review_system_note_enabled?
      ).execute
    end

    def review_bot
      Users::Internal.duo_code_review_bot
    end

    def duo_code_review_system_note_enabled?
      ::Feature.enabled?(:duo_code_review_system_note, resource.project)
    end
  end
end
