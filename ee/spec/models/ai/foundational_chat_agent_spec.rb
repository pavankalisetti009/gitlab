# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FoundationalChatAgent, feature_category: :workflow_catalog do
  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(ActiveRecord::FixedItemsModel::Model) }
    it { is_expected.to include(GlobalID::Identification) }
    it { is_expected.to include(Ai::FoundationalChatAgentsDefinitions) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:reference) }
    it { is_expected.to validate_presence_of(:description) }
  end

  describe 'duo_chat?' do
    context 'when duo chat' do
      it 'is true' do
        expect(described_class.all[0]).to be_duo_chat
      end
    end

    context 'when not duo chat' do
      it 'is true' do
        expect(described_class.all[1]).not_to be_duo_chat
      end
    end
  end

  describe '#count' do
    it 'returns the correct count of agents' do
      expect(described_class.count).to eq(described_class::ITEMS.size)
    end
  end

  describe '#workflow_definitions' do
    it 'is expected to return all workflow definitions' do
      expect(described_class.workflow_definitions.size).to be(described_class.count)
      expect(described_class.workflow_definitions[0]).to eq('chat')
    end
  end

  describe '#reference_with_version' do
    context 'when version is present' do
      it 'returns reference with version' do
        agent = described_class.new(reference: 'security_analyst_agent', version: 'v1')

        expect(agent.reference_with_version).to eq('security_analyst_agent/v1')
      end
    end

    context 'when version is blank' do
      it 'returns only reference' do
        agent = described_class.new(reference: 'chat', version: '')

        expect(agent.reference_with_version).to eq('chat')
      end
    end

    context 'when version is nil' do
      it 'returns only reference' do
        agent = described_class.new(reference: 'chat', version: nil)

        expect(agent.reference_with_version).to eq('chat')
      end
    end
  end

  describe '#workflow_definition' do
    it 'is the same as reference_with_version' do
      agent = described_class.new(reference: 'security_analyst_agent', version: 'v1')

      expect(agent.workflow_definition).to eq('security_analyst_agent/v1')
    end
  end

  describe '#foundational_workflow_definition?' do
    it 'returns true for chat' do
      expect(described_class.foundational_workflow_definition?('chat')).to be(true)
    end

    context 'if matching agent exists' do
      it 'returns true' do
        expect(described_class.foundational_workflow_definition?('duo_planner/v1')).to be(true)
      end
    end

    context 'if matching agent does not exist' do
      it 'returns false' do
        expect(described_class.foundational_workflow_definition?('some_agent')).to be(false)
      end
    end
  end

  describe '#reference_from_workflow_definition' do
    let(:workflow_definition) { 'security_analyst_agent/v1' }

    subject(:reference_from_workflow_definition) do
      described_class.reference_from_workflow_definition(workflow_definition)
    end

    it 'returns reference from workflow definition' do
      is_expected.to eq('security_analyst_agent')
    end

    context 'when version is blank' do
      let(:workflow_definition) { 'security_analyst_agent' }

      it 'returns reference from workflow definition' do
        is_expected.to eq('security_analyst_agent')
      end
    end
  end

  describe '#to_global_id' do
    context 'when version is present' do
      it 'returns reference with version' do
        agent = described_class.new(reference: 'security_analyst_agent', version: 'v1')

        expect(agent.to_global_id).to eq('security_analyst_agent-v1')
      end
    end

    context 'when version is blank' do
      it 'returns reference with blank version' do
        agent = described_class.new(reference: 'chat', version: '')

        expect(agent.to_global_id).to eq('chat')
      end
    end

    context 'when version is nil' do
      it 'returns reference with blank version' do
        agent = described_class.new(reference: 'chat', version: nil)

        expect(agent.to_global_id).to eq('chat')
      end
    end
  end

  describe '#only_duo_chat' do
    it 'returns only duo chat' do
      only_chat = described_class.only_duo_chat_agent
      expect(only_chat.size).to eq(1)
      expect(only_chat[0].name).to eq('GitLab Duo')
    end
  end

  describe '#except_duo_chat_agent' do
    it 'returns all but duo chat' do
      expect_duo_chat = described_class.except_duo_chat_agent
      expect(expect_duo_chat.size).to eq(described_class::ITEMS.size - 1)
      expect(expect_duo_chat.map(&:name)).not_to include('GitLab Duo')
    end
  end

  describe '#any_agents_with_reference?' do
    it 'is true if reference for foundational agent' do
      expect(described_class.any_agents_with_reference?('duo_planner')).to be true
    end

    it 'is false if reference not for foundational agent' do
      expect(described_class.any_agents_with_reference?('invalid_agent_1')).to be false
    end
  end

  describe '#with_workflow_definition' do
    context 'when agent with workflow definition exists' do
      it 'returns the agent for chat without version' do
        agent = described_class.with_workflow_definition('chat')

        expect(agent).not_to be_nil
        expect(agent.reference).to eq('chat')
        expect(agent.name).to eq('GitLab Duo')
      end

      it 'returns the agent for workflow definition with version' do
        agent = described_class.with_workflow_definition('duo_planner/v1')

        expect(agent).not_to be_nil
        expect(agent.reference).to eq('duo_planner')
        expect(agent.version).to eq('v1')
        expect(agent.name).to eq('Planner')
      end

      it 'returns the agent for analytics agent' do
        agent = described_class.with_workflow_definition('analytics_agent/v1')

        expect(agent).not_to be_nil
        expect(agent.reference).to eq('analytics_agent')
        expect(agent.version).to eq('v1')
        expect(agent.name).to eq('Data Analyst')
      end
    end

    context 'when agent with workflow definition does not exist' do
      it 'returns nil' do
        agent = described_class.with_workflow_definition('nonexistent_agent/v1')

        expect(agent).to be_nil
      end
    end
  end
end
