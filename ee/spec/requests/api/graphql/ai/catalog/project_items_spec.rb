# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project.aiCatalogItems', :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:guest_user) { create(:user) }
  let_it_be(:developer_user) { create(:user) }
  let_it_be(:project) { create(:project, developers: developer_user, guests: guest_user) }
  let_it_be(:other_project) { create(:project) }

  let_it_be(:flow) { create(:ai_catalog_flow, project: project) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }

  let_it_be(:private_agent_of_other_project) { create(:ai_catalog_agent, :private, project: other_project) }
  let_it_be(:public_agent_of_other_project) { create(:ai_catalog_agent, :public, project: other_project) }

  let(:nodes) { graphql_data_at(:project, :ai_catalog_items, :nodes) }
  let(:args) { {} }

  let(:current_user) { developer_user }

  let(:query) do
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_graphql_field(:ai_catalog_items, attributes_to_graphql(args).to_s,
        query_graphql_field(:nodes, {}, all_graphql_fields_for('AiCatalogItem'))
      )
    )
  end

  before do
    enable_ai_catalog
  end

  it 'returns items belonging to the project' do
    post_graphql(query, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(nodes).to contain_exactly(
      a_graphql_entity_for(flow),
      a_graphql_entity_for(agent)
    )
  end

  context 'when user is not a developer+ of the project' do
    let(:current_user) { guest_user }

    it 'returns no items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end

  context 'when the `global_ai_catalog` flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it 'returns no items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end

  context 'when filtering by `item_types`' do
    let(:args) { super().merge(item_types: [:AGENT]) }

    it 'returns the matching items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to contain_exactly(
        a_graphql_entity_for(agent)
      )
    end
  end

  context 'when filtering by `enabled`' do
    let(:args) { super().merge(enabled: true) }

    before_all do
      create(:ai_catalog_item_consumer, item: flow, project: project)
    end

    it 'returns the matching items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to contain_exactly(
        a_graphql_entity_for(flow)
      )
    end
  end

  context 'when filtering by `all_available`' do
    let(:args) { super().merge(all_available: true) }

    it 'returns all available items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to contain_exactly(
        a_graphql_entity_for(agent),
        a_graphql_entity_for(flow),
        a_graphql_entity_for(public_agent_of_other_project)
      )
    end
  end

  context 'when filtering by `search`' do
    let(:args) { super().merge(search: 'triage') }

    let_it_be(:issue_label_agent) { create(:ai_catalog_agent, name: 'Autotriager', project: project) }
    let_it_be(:mr_review_flow) { create(:ai_catalog_flow, project: project, description: 'Flow to triage issues') }

    it 'returns items that partial match on the name or description' do
      post_graphql(query, current_user: current_user)

      expect(nodes).to contain_exactly(
        a_graphql_entity_for(issue_label_agent),
        a_graphql_entity_for(mr_review_flow)
      )
    end
  end
end
