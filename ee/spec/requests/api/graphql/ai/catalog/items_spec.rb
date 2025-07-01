# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI catalog items', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:catalog_items) { create_list(:ai_catalog_item, 2) }
  let(:nodes) { graphql_data_at(:ai_catalog_items, :nodes) }

  let(:query) do
    "{ #{query_nodes('AiCatalogItems')} }"
  end

  it 'returns AI catalog items' do
    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    expect(nodes).to match_array(catalog_items.map { |item| a_graphql_entity_for(item) })
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it 'returns no AI catalog items' do
      post_graphql(query, current_user: nil)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end
end
