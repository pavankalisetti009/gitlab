# frozen_string_literal: true

module Security
  class PipelineExecutionPolicyConfigLink < ApplicationRecord
    self.table_name = 'security_pipeline_execution_policy_config_links'

    belongs_to :project
    belongs_to :security_policy, class_name: 'Security::Policy',
      inverse_of: :security_pipeline_execution_policy_config_link

    validates :security_policy, uniqueness: { scope: :project_id }
  end
end
