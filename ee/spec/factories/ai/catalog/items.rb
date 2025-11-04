# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item, class: 'Ai::Catalog::Item' do
    agent
    sequence(:name) { |n| "Item #{n}" }
    sequence(:description) { |n| "Item #{n}" }

    factory :ai_catalog_agent, traits: [:agent]
    factory :ai_catalog_flow, traits: [:flow]
    factory :ai_catalog_third_party_flow, traits: [:third_party_flow]

    trait :agent do
      item_type { 'agent' }
    end

    trait :flow do
      item_type { 'flow' }
    end

    trait :third_party_flow do
      item_type { 'third_party_flow' }
    end

    trait :public do
      public { true }
    end

    trait :private do
      public { false }
    end

    trait :soft_deleted do
      deleted_at { Time.zone.now }
    end

    versions do |item|
      version_factory = "ai_catalog_#{item.item_type}_version"
      build_list(version_factory, 1, item: nil)
    end

    after(:build) do |item, _|
      item.latest_version ||= item.versions.first

      item.organization ||=
        # The ordering of Organizations by created_at does not match ordering by the id column.
        # This is because Organization::DEFAULT_ORGANIZATION_ID is 1, but in the specs the default
        # organization may get created after another organization.
        Organizations::Organization.where(visibility_level: Gitlab::VisibilityLevel::PUBLIC).order(:created_at).first ||
        # We create an organization next even though we are building here. We need to ensure
        # that an organization exists so other entities can belong to the same organization
        build(:organization) # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- unable to create with association()
    end
  end
end
