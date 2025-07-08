# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an AI catalog item', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:catalog_item) { create(:ai_catalog_item, :with_version) }
  let(:latest_version) { catalog_item.versions.last }
  let(:data) { graphql_data_at(:ai_catalog_item) }
  let(:params) { { id: catalog_item.to_global_id } }

  let(:query) do
    <<~GRAPHQL
      {
        aiCatalogItem(id: "#{params[:id]}") {
          description
          id
          itemType
          name
          versions {
            count
            nodes {
              id
              updatedAt
              createdAt
              publishedAt
              versionName
              ... on AiCatalogAgentVersion {
                systemPrompt
                userPrompt
              }
            }
          }
        }
      }
    GRAPHQL
  end

  it 'returns the AI catalog item with its versions' do
    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    expect(data).to match(
      hash_including(
        'id' => catalog_item.to_global_id.to_s,
        'name' => catalog_item.name,
        'description' => catalog_item.description,
        'itemType' => 'AGENT',
        'versions' => hash_including(
          'count' => 1,
          'nodes' => contain_exactly(
            hash_including(
              'id' => latest_version.to_global_id.to_s,
              'systemPrompt' => latest_version.definition['system_prompt'],
              'userPrompt' => latest_version.definition['user_prompt'],
              'updatedAt' => latest_version.updated_at.iso8601,
              'publishedAt' => latest_version.release_date&.iso8601,
              'versionName' => latest_version.version,
              'createdAt' => latest_version.created_at.iso8601
            )
          )
        )
      )
    )
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
