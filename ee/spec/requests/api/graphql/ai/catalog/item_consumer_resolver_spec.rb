# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a single AI catalog item consumer', feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:developer) { create(:user) }
  let_it_be(:project) { create(:project, :public, developers: developer) }
  let_it_be(:item) { create(:ai_catalog_agent, project:) }
  let_it_be(:item_version_v1_5_0) { create(:ai_catalog_agent_version, :released, version: '1.5.0', item: item) }
  let_it_be(:item_version_v1_6_0) { create(:ai_catalog_agent_version, :released, version: '1.6.0', item: item) }
  let_it_be(:item_consumer) do
    create(:ai_catalog_item_consumer, project: project, item: item, pinned_version_prefix: '1.5.0')
  end

  let(:current_user) { developer }
  let(:item_consumer_gid) { item_consumer.to_global_id }
  let(:item_consumer_data) { graphql_data_at(:ai_catalog_item_consumer) }

  let(:query) do
    <<~QUERY
      query($id: AiCatalogItemConsumerID!) {
        aiCatalogItemConsumer(id: $id) {
          id
          project {
            id
            name
          }
          item {
            id
            name
          }
          pinnedItemVersion {
            id
          }
          pinnedVersionPrefix
        }
      }
    QUERY
  end

  let(:variables) { { id: item_consumer_gid } }

  before do
    enable_ai_catalog
  end

  it 'returns the AI catalog item consumer' do
    post_graphql(query, current_user:, variables:)

    expect(response).to have_gitlab_http_status(:success)
    expect(item_consumer_data).to include(
      'id' => item_consumer.to_global_id.to_s,
      'project' => {
        'id' => project.to_global_id.to_s,
        'name' => project.name
      },
      'item' => {
        'id' => item.to_global_id.to_s,
        'name' => item.name
      },
      'pinnedItemVersion' => a_graphql_entity_for(item_version_v1_5_0),
      'pinnedVersionPrefix' => item_consumer.pinned_version_prefix
    )
  end

  context 'when pinnedItemVersion cannot resolve to a version' do
    before do
      item_consumer.update!(pinned_version_prefix: '2.0.1')
    end

    it 'returns null' do
      post_graphql(query, current_user:, variables:)

      expect(response).to have_gitlab_http_status(:success)
      expect(item_consumer_data).to include(
        'id' => item_consumer.to_global_id.to_s,
        'pinnedItemVersion' => nil
      )
    end
  end

  context 'with invalid ID' do
    let(:variables) { { id: "gid://gitlab/Ai::Catalog::ItemConsumer/#{non_existing_record_id}" } }

    it 'returns null' do
      post_graphql(query, current_user:, variables:)

      expect(response).to have_gitlab_http_status(:success)
      expect(item_consumer_data).to be_nil
    end
  end

  context 'when user lacks permissions' do
    let(:current_user) { create(:user) }

    it 'returns null due to authorization' do
      post_graphql(query, current_user:, variables:)

      expect(response).to have_gitlab_http_status(:success)
      expect(item_consumer_data).to be_nil
    end
  end

  context 'when user is not authenticated' do
    let(:current_user) { nil }

    it 'returns null' do
      post_graphql(query, current_user:, variables:)

      expect(response).to have_gitlab_http_status(:success)
      expect(item_consumer_data).to be_nil
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it 'returns null' do
      post_graphql(query, current_user:, variables:)

      expect(response).to have_gitlab_http_status(:success)
      expect(item_consumer_data).to be_nil
    end
  end
end
