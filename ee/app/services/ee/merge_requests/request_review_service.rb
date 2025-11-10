# frozen_string_literal: true

module EE
  module MergeRequests
    module RequestReviewService
      extend ::Gitlab::Utils::Override

      override :with_valid_reviewer
      def with_valid_reviewer(merge_request, user)
        if user == duo_code_review_bot && !merge_request.ai_review_merge_request_allowed?(current_user)
          return error(::Ai::CodeReview.manual_error_message)
        end

        super
      end
    end
  end
end
