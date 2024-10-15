# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ComplianceRequirement < ApplicationRecord
      self.table_name = 'compliance_requirements'

      MAX_COMPLIANCE_REQUIREMENTS_PER_FRAMEWORK_COUNT = 50

      belongs_to :framework, class_name: 'ComplianceManagement::Framework', optional: false

      validates_presence_of :framework, :namespace_id, :name, :description
      validates :name, uniqueness: { scope: :framework_id }
      validate :requirements_count_per_framework

      has_many :security_policy_requirements,
        class_name: 'ComplianceManagement::ComplianceFramework::SecurityPolicyRequirement'

      has_many :compliance_framework_security_policies,
        through: :security_policy_requirements,
        inverse_of: :compliance_requirements

      private

      def requirements_count_per_framework
        if framework.nil? || framework.compliance_requirements.count < MAX_COMPLIANCE_REQUIREMENTS_PER_FRAMEWORK_COUNT
          return
        end

        errors.add(:framework, format(_("cannot have more than %{count} requirements"),
          count: MAX_COMPLIANCE_REQUIREMENTS_PER_FRAMEWORK_COUNT))
      end
    end
  end
end
