# frozen_string_literal: true

module Security
  module PipelineExecutionPolicies
    class RunScheduleWorker
      include ApplicationWorker

      idempotent!

      data_consistency :sticky
      feature_category :security_policy_management

      def perform(schedule_id)
        # no-op, will be implemented as part of https://gitlab.com/gitlab-org/gitlab/-/issues/504091
      end
    end
  end
end
