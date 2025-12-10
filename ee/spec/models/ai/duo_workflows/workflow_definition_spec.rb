# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowDefinition, feature_category: :duo_agent_platform do
  describe '.[]' do
    subject(:definition) { described_class[name] }

    context 'with a valid name' do
      let(:name) { 'code_review/v1' }

      it { is_expected.to eq(described_class.find_by(name: name)) }
    end

    context 'with a invalid name' do
      let(:name) { 'foo' }

      it { is_expected.to be_nil }
    end
  end

  describe '#agent_privileges' do
    subject(:agent_privileges) { definition.agent_privileges }

    context 'with empty agent_privileges' do
      let(:definition) { described_class.new(agent_privileges: [], pre_approved_agent_privileges: [1, 2]) }

      it 'copies pre_approved_agent_privileges' do
        expect(agent_privileges).to match_array([1, 2])
      end
    end

    context 'when agent_privileges are not set' do
      let(:definition) { described_class.new(agent_privileges: nil) }

      it 'returns the default value' do
        expect(agent_privileges).to eq([])
      end
    end

    context 'with agent_privileges' do
      let(:definition) { described_class.new(agent_privileges: [1, 2]) }

      it 'returns the agent_privileges' do
        expect(agent_privileges).to match_array([1, 2])
      end
    end
  end

  describe '#as_json' do
    subject(:as_json) { definition.as_json }

    let(:definition) do
      described_class.new(
        name: 'foo',
        ai_feature: 'bar',
        agent_privileges: [1, 2, 3],
        pre_approved_agent_privileges: [1, 2],
        allow_agent_to_request_user: true,
        environment: 'ambient'
      )
    end

    let(:expected_hash) do
      {
        workflow_definition: 'foo',
        agent_privileges: [1, 2, 3],
        pre_approved_agent_privileges: [1, 2],
        allow_agent_to_request_user: true,
        environment: 'ambient'
      }
    end

    it { is_expected.to eq(expected_hash) }
  end

  describe '#description' do
    subject(:description) { definition.description }

    context 'when description is set' do
      let(:definition) { described_class.find_by(name: 'code_review/v1') }

      it 'returns the description' do
        expect(description).to eq('GitLab Code Review')
      end
    end

    context 'when description is not set' do
      let(:definition) { described_class.new(name: 'test/v1', ai_feature: 'test') }

      it 'returns nil' do
        expect(description).to be_nil
      end
    end
  end

  describe '#foundational_flow_reference' do
    subject(:foundational_flow_reference) { definition.foundational_flow_reference }

    context 'when foundational_flow_reference is set' do
      let(:definition) { described_class.find_by(name: 'code_review/v1') }

      it 'returns the foundational_flow_reference' do
        expect(foundational_flow_reference).to eq('code_review/v1')
      end
    end

    context 'when foundational_flow_reference is not set' do
      let(:definition) { described_class.new(name: 'test/v1', ai_feature: 'test') }

      it 'returns nil' do
        expect(foundational_flow_reference).to be_nil
      end
    end
  end

  describe 'ITEMS' do
    it 'includes foundational workflows with required attributes' do
      foundational_workflows = described_class::ITEMS.select do |item|
        item[:foundational_flow_reference].present?
      end

      expect(foundational_workflows.size).to be >= 3

      foundational_workflows.each do |workflow|
        expect(workflow[:foundational_flow_reference]).to be_present
        expect(workflow[:description]).to be_present
        expect(workflow[:name]).to be_present
      end
    end

    it 'allows workflows without foundational_flow_reference' do
      all_items = described_class::ITEMS
      foundational_items = all_items.select { |item| item[:foundational_flow_reference].present? }

      # It's ok if there are more items than foundational ones
      expect(all_items.size).to be >= foundational_items.size
    end
  end
end
