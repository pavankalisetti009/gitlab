# frozen_string_literal: true

RSpec.shared_examples 'settings with foundational agents statuses' do
  include_context 'with mocked Foundational Chat Agents'

  it { is_expected.to include_module(Ai::FoundationalAgentsStatusable) }

  describe 'associations' do
    it { expect(instance).to have_many(:foundational_agents_status_records) }
  end

  let(:valid_enabled_status) { [{ reference: foundational_chat_agent_1_ref, enabled: true }] }

  before do
    instance.errors.clear
  end

  describe '#foundational_agents_statuses=' do
    it 'does not update when value is nil' do
      instance.foundational_agents_statuses = valid_enabled_status

      instance.foundational_agents_statuses = nil

      expect(instance.reload.foundational_agents_status_records.size).to eq 1
      expect(instance.foundational_agents_status_records[0].reference).to eq foundational_chat_agent_1_ref
      expect(instance.foundational_agents_status_records[0].enabled).to be true
    end

    it 'updates when value is empty' do
      instance.foundational_agents_statuses = valid_enabled_status

      instance.foundational_agents_statuses = []

      expect(instance.reload.foundational_agents_status_records).to eq([])
    end

    it 'rollbacks if an error happens' do
      instance.update!(foundational_agents_status_records: [])

      instance.foundational_agents_statuses = [*valid_enabled_status, { enabled: true }]

      expect(instance.errors.messages[:foundational_agents_statuses]).not_to be_empty

      expect(instance.reload.foundational_agents_status_records).to be_empty
    end

    it 'raises an error for invalid reference' do
      statuses = [
        { reference: 'invalid_agent', enabled: true }
      ]

      instance.foundational_agents_statuses = statuses

      expect(instance.errors.messages[:foundational_agents_statuses])
        .to include("Reference is not a valid foundational agent reference")
    end

    it 'replaces existing records' do
      instance.foundational_agents_statuses = valid_enabled_status
      instance.foundational_agents_statuses = [{ reference: foundational_chat_agent_2_ref, enabled: false }]

      records = instance.reload.foundational_agents_status_records
      expect(records.size).to eq 1
      expect(records[0].reference).to eq foundational_chat_agent_2_ref
      expect(records[0].enabled).to be false
    end
  end

  describe '#foundational_agents_statuses' do
    before do
      instance.foundational_agents_statuses = valid_enabled_status
    end

    it 'includes agent metadata from FoundationalChatAgent definitions' do
      statuses = instance.reload.foundational_agents_statuses

      agent_1_status = statuses.find { |a| a[:reference] == foundational_chat_agent_1_ref }

      expect(agent_1_status[:name]).to eq(foundational_chat_agent_1[:name])
      expect(agent_1_status[:description]).to eq(foundational_chat_agent_1[:description])
      expect(agent_1_status[:enabled]).to be true

      agent_2_status = statuses.find { |a| a[:reference] == foundational_chat_agent_2_ref }

      expect(agent_2_status[:name]).to eq(foundational_chat_agent_2[:name])
      expect(agent_2_status[:description]).to eq(foundational_chat_agent_2[:description])
      expect(agent_2_status[:enabled]).to be_nil
    end
  end
end
