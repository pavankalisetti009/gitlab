# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::FoundationalFlow, feature_category: :duo_agent_platform do
  describe '.[]' do
    subject(:definition) { described_class[key] }

    context 'with a valid name' do
      let(:key) { 'code_review/v1' }

      it { is_expected.to eq(described_class.find_by(name: key)) }
    end

    context 'with a valid display_name (for backward compatibility)' do
      let(:key) { 'Code Review' }

      it { is_expected.to eq(described_class.find_by(display_name: key)) }
    end

    context 'with a invalid key' do
      let(:key) { 'foo' }

      it { is_expected.to be_nil }
    end
  end

  describe '.beta?' do
    subject(:beta?) { described_class.beta?(foundational_flow_reference) }

    context 'when foundational flow is beta' do
      let(:foundational_flow_reference) { 'sast_fp_detection/v1' }

      it { is_expected.to be true }
    end

    context 'when foundational flow is GA' do
      let(:foundational_flow_reference) { 'code_review/v1' }

      it { is_expected.to be false }
    end

    context 'when foundational flow does not exist' do
      let(:foundational_flow_reference) { 'non_existent/v1' }

      it { is_expected.to be false }
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

  describe '#catalog_item' do
    subject(:catalog_item) { definition.catalog_item }

    context 'with foundational_flow_reference' do
      let_it_be(:definition) { described_class.new(foundational_flow_reference: 'code_review') }
      let_it_be(:duo_code_review) { create(:ai_catalog_item, foundational_flow_reference: 'code_review') }

      it 'returns the corresponding foundational workflow catalog item' do
        expect(catalog_item).to eq(duo_code_review)
      end
    end

    context 'without foundational_flow_reference' do
      let_it_be(:definition) { described_class.new(foundational_flow_reference: nil) }

      it 'returns nil' do
        expect(catalog_item).to be_nil
      end
    end

    context 'when the corresponding foundational workflow does not exist' do
      let_it_be(:definition) { described_class.new(foundational_flow_reference: 'code_review') }

      it 'returns nil' do
        expect(catalog_item).to be_nil
      end
    end
  end

  describe '#description' do
    subject(:description) { definition.description }

    context 'when description is set' do
      let(:definition) { described_class.find_by(name: 'code_review/v1') }

      it 'returns the description' do
        expect(description).to eq('Streamline code reviews by analyzing code changes, comments, and linked issues.')
      end
    end

    context 'when description is not set' do
      let(:definition) { described_class.new(name: 'test/v1', ai_feature: 'test') }

      it 'returns nil' do
        expect(description).to be_nil
      end
    end
  end

  describe '#display_name' do
    subject(:display_name) { definition.display_name }

    context 'when display_name is set' do
      let(:definition) { described_class.find_by(name: 'code_review/v1') }

      it 'returns the display_name without /v1' do
        expect(display_name).to eq('Code Review')
      end
    end

    context 'when display_name is not set' do
      let(:definition) { described_class.new(workflow_definition: 'test/v1', name: 'test/v1', ai_feature: 'test') }

      it 'returns nil' do
        expect(display_name).to be_nil
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

      expect(foundational_workflows.size).to be >= 6

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

    it 'has name with /v1 suffix and display_name without' do
      described_class::ITEMS.each do |workflow|
        expect(workflow[:name]).to include('/v1')
        expect(workflow[:display_name]).not_to include('/v1')
      end
    end
  end
end
