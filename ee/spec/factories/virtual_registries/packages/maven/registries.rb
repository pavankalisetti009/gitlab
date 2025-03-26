# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_maven_registry, class: 'VirtualRegistries::Packages::Maven::Registry' do
    group

    trait :with_upstream do
      registry_upstreams do
        [
          association(:virtual_registries_packages_maven_registry_upstream, group: group)
        ]
      end

      after(:create) do |entry, _|
        entry.reload # required so that registry.upstreams properly works
      end
    end
  end
end
