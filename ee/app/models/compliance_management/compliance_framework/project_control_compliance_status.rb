# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ProjectControlComplianceStatus < ApplicationRecord
      belongs_to :compliance_requirements_control
      belongs_to :project
      belongs_to :namespace
      belongs_to :compliance_requirement

      enum status: {
        pass: 0,
        fail: 1
      }

      validates :project_id, uniqueness: { scope: :compliance_requirements_control_id }
      validates_presence_of :status, :project, :namespace, :compliance_requirement,
        :compliance_requirements_control
    end
  end
end
