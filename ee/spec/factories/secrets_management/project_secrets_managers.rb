# frozen_string_literal: true

FactoryBot.define do
  factory :project_secrets_manager, class: 'SecretsManagement::ProjectSecretsManager' do
    project

    trait :active do
      status { SecretsManagement::ProjectSecretsManager::STATUSES[:active] }
    end

    trait :disabled do
      status { SecretsManagement::ProjectSecretsManager::STATUSES[:disabled] }
    end
  end
end
