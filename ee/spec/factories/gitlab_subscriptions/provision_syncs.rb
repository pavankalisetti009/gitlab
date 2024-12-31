# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription_provision_sync, class: 'GitlabSubscriptions::ProvisionSync' do
    namespace
    sync_requested_at { Time.current }
    attrs { { plan: "ultimate" } }
  end
end
