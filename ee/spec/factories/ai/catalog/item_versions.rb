# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item_version, class: 'Ai::Catalog::ItemVersion' do
    sequence(:version) { |n| "#{n}.0.99" }
    schema_version { 1 }
    for_agent
    release_date { nil }

    factory :ai_catalog_agent_version, traits: [:for_agent]
    factory :ai_catalog_flow_version, traits: [:for_flow]
    factory :ai_catalog_third_party_flow_version, traits: [:for_third_party_flow]

    trait :released do
      release_date { Time.current }
    end

    trait :draft do
      release_date { nil }
    end

    trait :for_agent do
      item { association :ai_catalog_agent }
      definition do
        {
          'system_prompt' => 'Talk like a pirate!',
          'tools' => [1],
          'user_prompt' => ''
        }
      end
    end

    trait :for_flow do
      item { association :ai_catalog_flow }
      definition do
        agent = Ai::Catalog::Item.find_by(item_type: :agent) || create(:ai_catalog_agent) # rubocop:disable RSpec/FactoryBot/InlineAssociation -- Not used for an association

        {
          'triggers' => [1],
          'steps' => [
            { 'agent_id' => agent.id, 'current_version_id' => agent.latest_version.id, 'pinned_version_prefix' => nil }
          ]
        }
      end
    end

    trait :for_third_party_flow do
      item { association :ai_catalog_third_party_flow }
      definition do
        {
          'injectGatewayToken' => true,
          'image' => 'node:22-slim',
          'commands' => ['/bin/bash'],
          'variables' => %w[VAL1 VAL2],
          'yaml_definition' => <<~YAML
            injectGatewayToken: true
            image: node:22-slim
            commands:
              - /bin/bash
            variables:
              - VAL1
              - VAL2
          YAML
        }
      end
    end

    after(:create) do |version, _|
      item = version.item
      item.latest_version = version
      item.latest_released_version = version if version.released?
      item.save!
    end
  end
end
