# frozen_string_literal: true

FactoryBot.define do
  factory :security_inventory_filters, class: 'Security::InventoryFilter' do
    project
    archived { false }

    Enums::Security.extended_analyzer_types.each_key do |analyzer_type|
      analyzer_type.to_sym { :not_configured }
    end

    total { 0 }
    critical { 0 }
    high { 0 }
    medium { 0 }
    low { 0 }
    info { 0 }
    unknown { 0 }

    after(:build) do |inventory_filter, _|
      inventory_filter.project_name = inventory_filter.project&.name
      inventory_filter.archived = inventory_filter.project&.archived
      inventory_filter.traversal_ids = inventory_filter.project&.namespace&.traversal_ids
    end

    trait :all_analyzers_enabled do
      sast { :enabled }
      secret_detection { :enabled }
      dependency_scanning { :enabled }
      container_scanning { :enabled }
      dast { :enabled }
      coverage_fuzzing { :enabled }
      api_fuzzing { :enabled }
    end

    trait :all_analyzers_disabled do
      sast { :disabled }
      secret_detection { :disabled }
      dependency_scanning { :disabled }
      container_scanning { :disabled }
      dast { :disabled }
      coverage_fuzzing { :disabled }
      api_fuzzing { :disabled }
    end

    trait :archived_project do
      after(:build) do |inventory_filter|
        inventory_filter.archived = true
      end
    end
  end
end
