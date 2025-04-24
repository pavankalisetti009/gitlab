# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::OrganizationClusterAgentsFinder, feature_category: :workspaces do
  let_it_be(:organization) { create(:organization) }

  let_it_be(:user) do
    create(:user).tap do |u|
      create(:organization_user, organization: organization, user: u)
    end
  end

  let(:filter) { :available }

  let_it_be(:mapped_agent_in_org) do
    project = create(:project, organization: organization, namespace: create(:group))
    create(:ee_cluster_agent, project: project, name: "agent-in-org-group-mapped").tap do |agent|
      create(:workspaces_agent_config, agent: agent)
      create(:organization_cluster_agent_mapping, user: user, agent: agent, organization: organization)
    end
  end

  let_it_be(:unmapped_agent_in_org) do
    project = create(:project, organization: organization)
    create(:ee_cluster_agent, project: project, name: "agent-in-org-group-unmapped").tap do |agent|
      create(:workspaces_agent_config, agent: agent)
    end
  end

  let_it_be(:agent_in_org_with_remote_dev_disabled) do
    project = create(:project, organization: organization)
    create(:ee_cluster_agent, project: project, name: "agent-in-org-unavailable").tap do |agent|
      create(:workspaces_agent_config, agent: agent, enabled: false)
      create(:organization_cluster_agent_mapping, user: user, agent: agent, organization: organization)
    end
  end

  describe '#execute' do
    subject(:response) do
      # noinspection RubyMismatchedArgumentType -- We are passing a test double
      described_class.execute(
        organization: organization,
        filter: filter,
        user: user
      ).to_a
    end

    context 'with filter_type set to available' do
      context 'when cluster agents are mapped to the organization' do
        it 'returns cluster agents mapped to the organization excluding those with remote dev disabled' do
          expect(response).to eq([mapped_agent_in_org])
        end
      end
    end

    context 'with filter_type set to directly_mapped' do
      let(:filter) { :directly_mapped }

      it 'returns cluster agents that are mapped directly to the organization, including those disabled' do
        expect(response).to match_array([mapped_agent_in_org, agent_in_org_with_remote_dev_disabled])
      end
    end

    context 'with filter_type set to unmapped' do
      let(:filter) { :unmapped }

      it 'returns cluster agents that are unmapped to the organization' do
        expect(response).to eq([unmapped_agent_in_org])
      end
    end

    context 'when user does not have adequate permissions' do
      let(:user) { create(:user) }

      it 'returns an empty response' do
        expect(response).to eq([])
      end
    end

    context 'with an invalid value for filter_type' do
      let(:filter) { "some_invalid_value" }

      it 'raises a RuntimeError' do
        expect { response }.to raise_error(RuntimeError, "Unsupported value for filter: #{filter}")
      end
    end
  end
end
