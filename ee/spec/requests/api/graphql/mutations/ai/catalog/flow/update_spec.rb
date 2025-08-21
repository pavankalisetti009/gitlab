# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Flow::Update, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be_with_reload(:flow) { create(:ai_catalog_flow, project: project) }
  let_it_be_with_reload(:latest_version) { create(:ai_catalog_flow_version, version: '1.1.0', item: flow) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be(:agent_v1) { create(:ai_catalog_agent_version, version: '1.0.0', item: agent) }
  let_it_be(:agent_v1_1) { create(:ai_catalog_agent_version, version: '1.1.0', item: agent) }

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_flow_update, params) do
      <<~MUTATION
      errors
      item {
        id
        name
        description
        public
      }
      MUTATION
    end
  end

  let(:mutation_response) { graphql_data_at(:ai_catalog_flow_update) }
  let(:params) do
    {
      id: flow.to_global_id,
      name: 'New name',
      public: true,
      description: 'New description',
      steps: [
        { agent_id: agent.to_global_id },
        { agent_id: agent.to_global_id, pinned_version_prefix: '1.0' }
      ]
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not update the flow' do
      expect { execute }.not_to change { flow.reload.attributes }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when user does not have access to a step agent' do
    let_it_be(:agent) { create(:ai_catalog_agent) }

    it 'returns the service error message and item with original attributes' do
      original_name = flow.name

      execute

      expect(graphql_dig_at(mutation_response, :item, :name)).to eq(original_name)
      expect(graphql_dig_at(mutation_response, :errors)).to contain_exactly('You have insufficient permissions')
    end
  end

  context 'when step agent does not exist' do
    let(:params) do
      super().merge(steps: [{ agent_id: global_id_of(id: non_existing_record_id, model_name: 'Ai::Catalog::Item') }])
    end

    it 'returns the service error message and item with original attributes' do
      original_name = flow.name

      execute

      expect(graphql_dig_at(mutation_response, :item, :name)).to eq(original_name)
      expect(graphql_dig_at(mutation_response, :errors)).to contain_exactly('You have insufficient permissions')
    end
  end

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the flow does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::Item', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when flow cannot be updated' do
    let(:params) { super().merge(name: nil) }

    it 'returns the service error message and item with original attributes' do
      original_name = flow.name

      execute

      expect(graphql_dig_at(mutation_response, :item, :name)).to eq(original_name)
      expect(graphql_dig_at(mutation_response, :errors)).to contain_exactly("Name can't be blank")
    end
  end

  context 'when update succeeds' do
    it 'updates the flow and returns a success response' do
      execute

      expect(flow.reload).to have_attributes(
        name: 'New name',
        description: 'New description',
        public: true
      )
      expect(latest_version.reload).to have_attributes(
        schema_version: 1,
        version: '1.1.0',
        definition: {
          steps: [
            {
              agent_id: agent.id, current_version_id: agent.latest_version.id, pinned_version_prefix: nil
            }.stringify_keys,
            {
              agent_id: agent.id, current_version_id: agent_v1.id, pinned_version_prefix: '1.0'
            }.stringify_keys
          ],
          triggers: [1]
        }.stringify_keys
      )
      expect(graphql_dig_at(mutation_response, :errors)).to be_empty
    end
  end
end
