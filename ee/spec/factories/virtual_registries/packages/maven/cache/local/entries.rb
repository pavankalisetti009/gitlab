# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_maven_cache_local_entry,
    class: 'VirtualRegistries::Packages::Maven::Cache::Local::Entry' do
    upstream do
      association :virtual_registries_packages_maven_upstream,
        :without_credentials,
        url: create(:project).to_global_id.to_s
    end
    group { upstream.group }
    package_file { association :package_file }
    sequence(:relative_path) { |n| "/a/relative/path/test-#{n}.txt" }

    after(:build) do |entry, _|
      entry.upstream.registry_upstreams.each { |registry_upstream| registry_upstream.group = entry.group }
    end
  end
end
