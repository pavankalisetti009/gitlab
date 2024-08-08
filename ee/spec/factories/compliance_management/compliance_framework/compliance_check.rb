# frozen_string_literal: true

FactoryBot.define do
  factory :compliance_check, class: 'ComplianceManagement::ComplianceFramework::ComplianceCheck' do
    association :compliance_requirement, factory: :compliance_requirement
    namespace_id { compliance_requirement.framework.namespace_id }
    check_name { :prevent_approval_by_merge_request_author }
  end
end
