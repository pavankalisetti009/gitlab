# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::FlowTriggers::Create, feature_category: :duo_workflow do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :repository, maintainers: maintainer) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_flow_trigger_create, params) }
  let(:description) { 'Description' }
  let(:event_types) { [Ai::FlowTrigger::EVENT_TYPES[:mention]] }
  let(:params) do
    {
      project_path: project.full_path,
      user_id: current_user.to_global_id,
      description: description,
      event_types: event_types,
      config_path: '.gitlab/duo/agents.yml'
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    allow(GitlabSubscriptions::AddOnPurchase).to receive_message_chain(
      :for_duo_enterprise,
      :active,
      :by_namespace,
      :assigned_to_user,
      :exists?
    ).and_return(true)
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a flow trigger' do
      expect { execute }.not_to change { Ai::FlowTrigger.count }
    end
  end

  context 'when user does not have permission' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when ai_flow_triggers feature flag is disabled' do
    before do
      stub_feature_flags(ai_flow_triggers: false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when graphql params are invalid' do
    let(:description) { nil }

    it 'returns the validation error' do
      execute

      expect(graphql_errors.first['message']).to include('description (Expected value to not be null)')
    end
  end

  context 'when model params are invalid' do
    let(:description) { 'a' * 256 }

    it 'returns the validation error' do
      execute

      expect(graphql_data_at(:ai_flow_trigger_create, :errors)).to contain_exactly(
        'Description is too long (maximum is 255 characters)'
      )
      expect(graphql_data_at(:ai_flow_trigger_create, :ai_flow_trigger)).to be_nil
    end
  end

  it 'creates a flow trigger with expected data' do
    execute

    trigger = Ai::FlowTrigger.last
    expect(trigger).to have_attributes(
      description: description,
      user_id: current_user.id,
      project_id: project.id,
      event_types: event_types,
      config_path: '.gitlab/duo/agents.yml'
    )
  end

  it 'returns the new trigger' do
    execute

    expect(graphql_data_at(:ai_flow_trigger_create, :ai_flow_trigger)).to match a_hash_including(
      'description' => description,
      'eventTypes' => event_types,
      'configPath' => '.gitlab/duo/agents.yml',
      'configUrl' => "/#{project.full_path}/-/blob/#{project.default_branch}/.gitlab/duo/agents.yml",
      'project' => a_hash_including('id' => project.to_global_id.to_s),
      'user' => a_hash_including('id' => current_user.to_global_id.to_s)
    )
  end
end
