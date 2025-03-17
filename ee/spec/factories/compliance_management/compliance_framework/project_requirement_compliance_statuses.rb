# frozen_string_literal: true

FactoryBot.define do
  factory :project_requirement_compliance_status,
    class: 'ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus' do
    compliance_requirement { association(:compliance_requirement) }
    compliance_framework { compliance_requirement.framework }
    project { association(:project, namespace: compliance_requirement.namespace) }
    namespace { project.group }
    pass_count { 1 }
    fail_count { 2 }
    pending_count { 1 }
  end
end
