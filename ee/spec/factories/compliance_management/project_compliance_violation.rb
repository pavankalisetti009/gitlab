# frozen_string_literal: true

FactoryBot.define do
  factory :project_compliance_violation, class: 'ComplianceManagement::Projects::ComplianceViolation' do
    namespace
    project { association :project, namespace: namespace }
    compliance_control { association :compliance_requirements_control, namespace: namespace }
    audit_event { association :project_audit_event, target_project: project }

    status { :detected }

    trait :in_review do
      status { :in_review }
    end

    trait :resolved do
      status { :resolved }
    end

    trait :dismissed do
      status { :dismissed }
    end
  end
end
