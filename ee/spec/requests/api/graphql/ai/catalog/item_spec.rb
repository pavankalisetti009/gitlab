# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an AI catalog item', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:catalog_item) { create(:ai_catalog_item) }
  let(:data) { graphql_data_at(:ai_catalog_item) }
  let(:params) { { id: catalog_item.to_global_id } }

  let(:query) do
    graphql_query_for('AiCatalogItem', params)
  end

  it 'returns AI catalog items' do
    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    expect(data).to match a_graphql_entity_for(catalog_item)
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it 'returns nil' do
      post_graphql(query, current_user: nil)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to be_nil
    end
  end

  context 'when the item does not exist' do
    let(:params) { { id: global_id_of(id: non_existing_record_id, model_name: 'Ai::Catalog::Item') } }

    it 'returns nil' do
      post_graphql(query, current_user: nil)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to be_nil
    end
  end
end
