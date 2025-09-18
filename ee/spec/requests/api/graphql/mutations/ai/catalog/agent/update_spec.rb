# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Agent::Update, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be_with_reload(:agent) { create(:ai_catalog_item, project: project) }
  let_it_be_with_reload(:latest_released_version) do
    create(:ai_catalog_item_version, :released, version: '1.0.0', item: agent)
  end

  let_it_be_with_reload(:latest_version) { create(:ai_catalog_item_version, version: '1.1.0', item: agent) }

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_agent_update, params) do
      <<~MUTATION
      errors
      item {
        id
        name
        description
        public
        latestVersion {
          id
          released
          ...on AiCatalogAgentVersion {
            userPrompt
            tools {
              nodes {
                id
              }
            }
            systemPrompt
          }
        }
      }
      MUTATION
    end
  end

  let(:mutation_response) { graphql_data_at(:ai_catalog_agent_update) }
  let(:tools) { Ai::Catalog::BuiltInTool.where(id: [1, 9]) }
  let(:params) do
    {
      id: agent.to_global_id,
      name: 'New name',
      public: true,
      description: 'New description',
      release: true,
      system_prompt: 'New system prompt',
      tools: tools.map { |tool| global_id_of(tool) },
      user_prompt: 'New user prompt',
      version_bump: 'PATCH'
    }
  end

  before do
    enable_ai_catalog
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not update the agent' do
      expect { execute }.not_to change { agent.reload.attributes }
    end

    it 'does not update the latest version' do
      expect { execute }.not_to change { latest_version.reload.attributes }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the agent does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::Item', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when agent cannot be updated' do
    let(:params) { super().merge(name: nil) }

    it 'returns the service error message and item with original attributes' do
      original_name = agent.name

      execute

      expect(graphql_dig_at(mutation_response, :item, :name)).to eq(original_name)
      expect(graphql_dig_at(mutation_response, :errors)).to contain_exactly("Name can't be blank")
    end
  end

  context 'when latest version cannot be updated' do
    before do
      stub_const('Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION', nil)
    end

    it 'returns the service error message' do
      execute

      expect(graphql_dig_at(mutation_response, :errors)).to contain_exactly(
        "Latest version schema version can't be blank", 'Latest version definition unable to validate definition'
      )
    end
  end

  context 'when update succeeds', :freeze_time do
    it 'updates the agent and its latest version, and returns a success response' do
      execute

      expect(agent.reload).to have_attributes(
        name: 'New name',
        description: 'New description',
        public: true
      )

      expect(latest_version.reload).to have_attributes(
        schema_version: 1,
        version: '1.0.1',
        release_date: Time.zone.now,
        definition: {
          system_prompt: 'New system prompt',
          tools: tools.map(&:id),
          user_prompt: 'New user prompt'
        }.stringify_keys
      )

      expect(graphql_dig_at(mutation_response, :item)).to match(
        a_graphql_entity_for(agent,
          :name,
          :description,
          :public,
          latest_version: a_graphql_entity_for(latest_version,
            released: true,
            system_prompt: latest_version.definition['system_prompt'],
            tools: {
              'nodes' => match_array(
                tools.map { |tool| a_graphql_entity_for(tool) }
              )
            },
            user_prompt: latest_version.definition['user_prompt']
          )
        )
      )
      expect(graphql_dig_at(mutation_response, :errors)).to be_empty
    end
  end

  context 'when update creates a new latest version' do
    it 'returns the correct version in latestVersion field' do
      latest_version.update!(release_date: Time.zone.now)

      execute

      agent.reload

      expect(graphql_dig_at(mutation_response, :item, :latest_version)).not_to match(
        a_graphql_entity_for(latest_version)
      )
      expect(graphql_dig_at(mutation_response, :item, :latest_version)).to match(
        a_graphql_entity_for(agent.latest_version)
      )
    end
  end
end
