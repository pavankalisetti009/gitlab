# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::FlowTriggers::Delete, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be_with_reload(:trigger) { create(:ai_flow_trigger, project: project) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_flow_trigger_delete, params) }
  let(:params) do
    {
      id: trigger.to_global_id
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

    it 'does not delete the flow trigger' do
      expect { execute }.not_to change { Ai::FlowTrigger.count }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when ai_flow_triggers feature flag is disabled' do
    before do
      stub_feature_flags(ai_flow_triggers: false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the flow trigger does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::FlowTrigger', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when destroy fails' do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(trigger).to receive(:destroy).and_return(false)
        allow(instance).to receive(:authorized_find!).and_return(trigger)
      end
    end

    it 'returns the service error message' do
      execute

      expect(graphql_data_at(:ai_flow_trigger_delete, :errors)).to contain_exactly('Failed to delete the flow trigger')
    end
  end

  it 'destroy the flow trigger' do
    expect { execute }.to change { Ai::FlowTrigger.count }.by(-1)
  end
end
