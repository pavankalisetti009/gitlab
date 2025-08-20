# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::ExecuteService, :aggregate_failures, feature_category: :duo_workflow do
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, organization: organization, maintainers: maintainer) }
  let_it_be(:agent) { create(:ai_catalog_agent, organization: organization, project: project) }
  let_it_be(:agent_version) { agent.versions.last }

  let(:current_user) { maintainer }

  let(:service) { described_class.new(agent, agent_version, current_user) }

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'returns error response' do |expected_message|
      it 'returns an error service response' do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq(expected_message)
      end
    end

    context 'with valid inputs' do
      it 'returns a successful service response with flow config' do
        result = execute

        expect(result).to be_success

        yaml_content = result[:flow_config]
        parsed_yaml = YAML.safe_load(yaml_content)
        expect(parsed_yaml).to include(
          'version' => 'experimental',
          'environment' => 'remote',
          'components' => be_an(Array),
          'routers' => be_an(Array),
          'flow' => be_a(Hash)
        )
      end
    end

    context 'when user lack permission' do
      let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

      it_behaves_like 'returns error response', 'You have insufficient permission to execute this agent'
    end

    context 'when agent is nil' do
      let(:service) { described_class.new(nil, agent_version, current_user) }

      it_behaves_like 'returns error response', 'Agent is required'
    end

    context 'when agent item_type is flow' do
      let(:service) { described_class.new(build(:ai_catalog_flow), agent_version, current_user) }

      it_behaves_like 'returns error response', 'Agent is required'
    end

    context 'when agent_version is nil' do
      let(:service) { described_class.new(agent, nil, current_user) }

      it_behaves_like 'returns error response', 'Agent version is required'
    end

    context 'when agent_version does not belong to the agent' do
      let(:other_agent) { build(:ai_catalog_agent, organization: organization, project: project) }
      let(:other_agent_version) { other_agent.versions.last }
      let(:service) { described_class.new(agent, other_agent_version, current_user) }

      it_behaves_like 'returns error response', 'Agent version must belong to the agent'
    end
  end
end
