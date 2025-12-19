# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_connection, class: 'Ai::ActiveContext::Connection' do
    sequence(:name) { |n| "connection_#{n}" }
    adapter_class { 'Ai::ActiveContext::Adapters::BaseAdapter' }
    active { true }
    options { { url: 'https://example.com', token: 'secret' } }
    prefix { 'test' }

    trait :inactive do
      active { false }
    end

    trait :elasticsearch do
      adapter_class { 'ActiveContext::Databases::Elasticsearch::Adapter' }
      options { { url: ENV['ELASTIC_URL'] || 'http://localhost:9200' } }
      prefix { ActiveContextHelpers::TEST_INDEX_PREFIX }
    end

    # Uses ELASTIC_URL in CI, localhost:9202 for local development.
    # To run tests locally, configure OpenSearch on port 9202.
    # https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/elasticsearch.md#opensearch
    trait :opensearch do
      adapter_class { 'ActiveContext::Databases::Opensearch::Adapter' }
      options { { url: ENV['ELASTIC_URL'] || 'http://localhost:9202' } }
      prefix { ActiveContextHelpers::TEST_INDEX_PREFIX }
    end
  end
end
