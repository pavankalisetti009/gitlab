# frozen_string_literal: true

FactoryBot.define do
  factory :compliance_requirements_control,
    class: 'ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl' do
    compliance_requirement
    namespace_id { compliance_requirement.namespace_id }
    name { 'minimum_approvals_required_2' }
    control_type { 'internal' }
    expression do
      {
        operator: "=",
        field: "minimum_approvals_required",
        value: 2
      }.to_json
    end

    trait :project_visibility_not_internal do
      name { 'project_visibility_not_internal' }
      expression do
        {
          operator: "=",
          field: "project_visibility",
          value: "private"
        }.to_json
      end
    end

    trait :scanner_sast_running do
      name { 'scanner_sast_running' }
      expression do
        {
          operator: "=",
          field: "scanner_sast_running",
          value: true
        }.to_json
      end
    end

    trait "external" do
      external_url { FFaker::Internet.unique.http_url }
      control_type { 'external' }
      secret_token { 'token' }
    end
  end
end
