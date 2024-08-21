# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ComplianceRequirement < ApplicationRecord
      self.table_name = 'compliance_requirements'

      belongs_to :framework, class_name: 'ComplianceManagement::Framework', optional: false

      validates_presence_of :framework, :namespace_id, :name, :description
      validates :name, uniqueness: { scope: :framework_id }

      has_many :compliance_checks, class_name: 'ComplianceManagement::ComplianceFramework::ComplianceCheck',
        foreign_key: :requirement_id, inverse_of: :compliance_requirement

      has_many :security_policy_requirements,
        class_name: 'ComplianceManagement::ComplianceFramework::SecurityPolicyRequirement'

      has_many :compliance_framework_security_policies,
        through: :security_policy_requirements,
        inverse_of: :compliance_requirements
    end
  end
end
