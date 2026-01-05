# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckApprovedService < CheckBaseService
      set_identifier :not_approved
      set_description 'Checks whether the merge request is approved'

      def execute
        return inactive unless merge_request.approval_feature_available?
        return checking if merge_request.temporarily_unapproved?
        return success if merge_request.approved?

        failure
      end

      def skip?
        params[:skip_approved_check].present?
      end

      def cacheable?
        false
      end
    end
  end
end
