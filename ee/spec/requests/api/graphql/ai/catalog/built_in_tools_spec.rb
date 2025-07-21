# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI catalog built-in tools', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let(:nodes) { graphql_data_at(:ai_catalog_built_in_tools, :nodes) }

  let(:query) do
    "{ #{query_nodes('AiCatalogBuiltInTools')} }"
  end

  it 'returns all built-in tools' do
    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    expect(nodes).to have_attributes(size: ::Ai::Catalog::BuiltInTool.count)

    first_node = nodes.first
    tool = ::Ai::Catalog::BuiltInTool.find_by(name: first_node['name'])
    expect(first_node).to match(a_graphql_entity_for(tool, :name, :title, :description))
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it 'returns empty array' do
      post_graphql(query, current_user: nil)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end
end
