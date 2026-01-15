# frozen_string_literal: true

FactoryBot.define do
  factory :project_secrets_manager_maintenance_task,
    class: 'SecretsManagement::ProjectSecretsManagerMaintenanceTask' do
    user
    project_secrets_manager

    action { :provision }
    last_processed_at { Time.zone.now }
    retry_count { 0 }

    trait :provision do
      action { :provision }
    end

    trait :deprovision do
      action { :deprovision }
    end

    trait :processing do
      last_processed_at { 1.minute.ago }
    end

    trait :stale do
      last_processed_at { 7.minutes.ago }
    end
  end
end
