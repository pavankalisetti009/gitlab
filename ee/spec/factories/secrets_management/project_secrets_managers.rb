# frozen_string_literal: true

FactoryBot.define do
  factory :project_secrets_managers, class: 'SecretsManagement::ProjectSecretsManager' do
    project
  end
end
