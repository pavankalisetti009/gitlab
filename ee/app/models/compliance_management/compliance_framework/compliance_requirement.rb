# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ComplianceRequirement < ApplicationRecord
      self.table_name = 'compliance_requirements'

      ignore_column :control_expression, remove_with: '17.11', remove_after: '2025-03-22'
      ignore_column :requirement_type, remove_with: '17.11', remove_after: '2025-03-22'

      MAX_COMPLIANCE_REQUIREMENTS_PER_FRAMEWORK_COUNT = 50

      belongs_to :framework, class_name: 'ComplianceManagement::Framework', optional: false
      belongs_to :namespace, optional: false

      validates_presence_of :framework, :namespace_id, :name, :description
      validates :name, uniqueness: { scope: :framework_id }
      validate :requirements_count_per_framework
      validates :name, :description, length: { maximum: 255 }
      validate :framework_belongs_to_same_namespace

      has_many :security_policy_requirements,
        class_name: 'ComplianceManagement::ComplianceFramework::SecurityPolicyRequirement'

      has_many :compliance_framework_security_policies,
        through: :security_policy_requirements,
        inverse_of: :compliance_requirements

      has_many :compliance_requirements_controls,
        class_name: 'ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl'
      has_many :project_control_compliance_statuses,
        class_name: 'ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus'
      has_many :project_requirement_compliance_statuses,
        class_name: 'ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus'

      def delete_compliance_requirements_controls
        ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl
          .where(compliance_requirement: self)
          .delete_all
      end

      private

      def requirements_count_per_framework
        if framework.nil? || framework.compliance_requirements.count < MAX_COMPLIANCE_REQUIREMENTS_PER_FRAMEWORK_COUNT
          return
        end

        errors.add(:framework, format(_("cannot have more than %{count} requirements"),
          count: MAX_COMPLIANCE_REQUIREMENTS_PER_FRAMEWORK_COUNT))
      end

      def framework_belongs_to_same_namespace
        return if namespace_id.nil? || framework.nil? || namespace_id == framework.namespace_id

        errors.add(:namespace, "must be the same as the framework's namespace.")
      end
    end
  end
end
