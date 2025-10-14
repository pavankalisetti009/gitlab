# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an AI catalog item', :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:catalog_item) { create(:ai_catalog_item, project: project, public: true) }

  let(:latest_version) { catalog_item.latest_version }
  let(:data) { graphql_data_at(:ai_catalog_item) }
  let(:params) { { id: catalog_item.to_global_id } }
  let(:query_args) { attributes_to_graphql(params) }
  let(:current_user) { nil }

  let(:query) do
    <<~GRAPHQL
      fragment VersionFragment on AiCatalogItemVersion {
        id
        updatedAt
        createdAt
        releasedAt
        released
        humanVersionName
        versionName
        ... on AiCatalogFlowVersion {
          steps {
            nodes {
              agent {
                name
              }
            }
          }
        }
        ... on AiCatalogAgentVersion {
          systemPrompt
          tools {
            nodes {
              id
            }
          }
          userPrompt
        }
      }

      query {
        aiCatalogItem(#{query_args}) {
          description
          id
          itemType
          name
          public
          project { id }
          latestVersion {
            ...VersionFragment
          }
          versions {
            count
            nodes {
              ...VersionFragment
            }
          }
        }
      }
    GRAPHQL
  end

  before do
    enable_ai_catalog
  end

  shared_examples 'a successful query' do
    it 'returns the AI catalog item with its versions' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to match(
        hash_including(
          'id' => catalog_item.to_global_id.to_s,
          'name' => catalog_item.name,
          'description' => catalog_item.description,
          'itemType' => 'AGENT',
          'public' => catalog_item.public,
          'latestVersion' => a_graphql_entity_for(latest_version),
          'versions' => hash_including(
            'count' => 1,
            'nodes' => contain_exactly(
              hash_including(
                'id' => latest_version.to_global_id.to_s,
                'systemPrompt' => latest_version.definition['system_prompt'],
                'userPrompt' => latest_version.definition['user_prompt'],
                'tools' => {
                  'nodes' => match_array(
                    latest_version.definition['tools'].map do |id|
                      a_graphql_entity_for(Ai::Catalog::BuiltInTool.find(id))
                    end
                  )
                },
                'updatedAt' => latest_version.updated_at.iso8601,
                'releasedAt' => latest_version.release_date&.iso8601,
                'released' => latest_version.released?,
                'versionName' => latest_version.version,
                'humanVersionName' => latest_version.human_version,
                'createdAt' => latest_version.created_at.iso8601
              )
            )
          )
        )
      )
    end
  end

  shared_examples 'an unsuccessful query' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to be_nil
    end
  end

  context 'with a public catalog item' do
    it_behaves_like 'a successful query'

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(global_ai_catalog: false)
      end

      it_behaves_like 'an unsuccessful query'
    end

    context 'when the item does not exist' do
      let(:params) { { id: global_id_of(id: non_existing_record_id, model_name: 'Ai::Catalog::Item') } }

      it_behaves_like 'an unsuccessful query'
    end
  end

  context 'with a private catalog item' do
    let_it_be(:catalog_item) { create(:ai_catalog_item, project: project) }

    context 'when developer' do
      let(:current_user) do
        create(:user).tap { |user| project.add_developer(user) }
      end

      it_behaves_like 'a successful query'
    end

    context 'when reporter' do
      let(:current_user) do
        create(:user).tap { |user| project.add_reporter(user) }
      end

      it_behaves_like 'an unsuccessful query'
    end
  end

  it 'returns the latest version when more than one exists' do
    latest_version = create(:ai_catalog_item_version, version: '2.1.0', item: catalog_item)

    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    expect(data).to match(
      a_graphql_entity_for(
        catalog_item,
        'latestVersion' => a_graphql_entity_for(latest_version)
      )
    )
  end

  context 'when requesting latestVersion(released: true)' do
    let(:latest_version_data) { graphql_data_at(:ai_catalog_item, :latest_version) }

    let(:query) do
      <<~GRAPHQL
        query {
          aiCatalogItem(id: "#{params[:id]}") {
            latestVersion(released: true) {
              id
            }
          }
        }
      GRAPHQL
    end

    it 'returns nil when there is no latest released version' do
      post_graphql(query, current_user: nil)

      expect(response).to have_gitlab_http_status(:success)
      expect(latest_version_data).to be_nil
    end

    context 'when there is a latest released version' do
      before do
        latest_version.update!(release_date: 1.day.ago)
        catalog_item.update!(latest_released_version: latest_version)
      end

      it 'returns the latest released version' do
        post_graphql(query, current_user: nil)

        expect(response).to have_gitlab_http_status(:success)
        expect(latest_version_data).to match(a_graphql_entity_for(latest_version))
      end
    end
  end

  context 'when item is a flow' do
    let_it_be(:flow) { create(:ai_catalog_flow, project: project, public: true) }
    let(:params) { { id: flow.to_global_id } }

    it 'resolves flow steps agents' do
      create(:ai_catalog_flow_version, item: flow, definition: {
        triggers: [],
        steps: [
          { agent_id: catalog_item.id, current_version_id: catalog_item.latest_version.id, pinned_version_prefix: nil }
        ]
      })

      post_graphql(query, current_user: nil)

      expect(graphql_data_at(:ai_catalog_item, :latest_version, :steps, :nodes)).to include(a_hash_including(
        'agent' => { 'name' => catalog_item.name }
      ))
    end
  end

  context 'when item belongs to another organization' do
    before do
      catalog_item.update!(organization: create(:organization), project: nil)
    end

    it_behaves_like 'an unsuccessful query'
  end

  context 'when item has been soft deleted' do
    let_it_be(:catalog_item) { create(:ai_catalog_item, public: true, project: project, deleted_at: 1.day.ago) }

    context 'when show_soft_deleted is not provided' do
      it_behaves_like 'an unsuccessful query'
    end

    context 'when show_soft_deleted is true' do
      let(:params) { super().merge(show_soft_deleted: true) }

      it_behaves_like 'a successful query'
    end

    context 'when show_soft_deleted is false' do
      let(:params) { super().merge(show_soft_deleted: false) }

      it_behaves_like 'an unsuccessful query'
    end
  end
end
