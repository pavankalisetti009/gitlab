# frozen_string_literal: true

module Security
  class ScheduledPipelineExecutionPolicyTestRun < ApplicationRecord
    self.table_name = 'security_scheduled_pipeline_execution_policy_test_runs'

    belongs_to :security_policy, class_name: 'Security::Policy'
    belongs_to :project
    belongs_to :pipeline, class_name: 'Ci::Pipeline'

    validates :security_policy, :project, presence: true
    validate :security_policy_is_pipeline_execution_schedule_policy

    enum :state, { running: 0, complete: 1, failed: 2 }, default: :running

    delegate :started_at, :finished_at, :duration, to: :pipeline, allow_nil: true

    before_save :truncate_error_message

    private

    def truncate_error_message
      self.error_message = error_message&.truncate(255, omission: '')
    end

    def security_policy_is_pipeline_execution_schedule_policy
      return unless security_policy

      return if security_policy.type_pipeline_execution_schedule_policy?

      errors.add(:security_policy, _('must be a pipeline execution schedule policy'))
    end
  end
end
