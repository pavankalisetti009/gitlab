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

  describe '.count' do
    it 'returns the correct count of tools' do
      expect(described_class.count).to eq(described_class::ITEMS.size)
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

        expect(agent.to_global_id).to eq('chat-')
      end
    end

    context 'when version is nil' do
      it 'returns reference with blank version' do
        agent = described_class.new(reference: 'chat', version: nil)

        expect(agent.to_global_id).to eq('chat-')
      end
    end
  end
end
