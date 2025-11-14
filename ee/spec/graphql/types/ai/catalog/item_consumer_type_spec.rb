# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::ItemConsumerType, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogItemConsumer')
  end

  it 'has the expected fields' do
    expected_fields = %w[
      group
      id
      enabled
      flow_trigger
      item
      organization
      parent_item_consumer
      pinned_item_version
      pinned_version_prefix
      service_account
      project
    ]

    expect(described_class.own_fields.size).to eq(expected_fields.size)
    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it { expect(described_class).to require_graphql_authorizations(:read_ai_catalog_item_consumer) }

  describe 'pinned_item_version field' do
    subject(:field) { described_class.fields['pinnedItemVersion'] }

    it 'limits field call count' do
      extension = field.extensions.find { |e| e.is_a?(::Gitlab::Graphql::Limit::FieldCallCount) }

      expect(extension).to be_present
      expect(extension.options).to eq(limit: 20)
    end
  end
end
