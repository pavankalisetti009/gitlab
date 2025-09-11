# frozen_string_literal: true

FactoryBot.define do
  factory :secret_rotation_info, class: 'SecretsManagement::SecretRotationInfo' do
    project
    sequence(:secret_name) { |n| "SECRET_#{n}" }
    rotation_interval_days { 30 }
    secret_metadata_version { 1 }
  end
end
