# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../app/models/search/zoekt/settings'

RSpec.describe Search::Zoekt::Settings, feature_category: :global_search do
  describe 'SETTINGS' do
    it 'defines expected settings' do
      expect(described_class::SETTINGS.keys).to include(
        :zoekt_indexing_enabled,
        :zoekt_search_enabled,
        :zoekt_indexing_paused,
        :zoekt_auto_index_root_namespace,
        :zoekt_auto_delete_lost_nodes,
        :zoekt_cpu_to_tasks_ratio
      )
    end

    it 'has proper structure for each setting' do
      described_class::SETTINGS.each_value do |config|
        expect(config).to have_key(:type)
        expect(config).to have_key(:default)
        expect(config).to have_key(:label)
        expect(config[:label]).to be_a(Proc)
      end
    end

    it 'has boolean settings with correct type' do
      boolean_settings = [
        :zoekt_indexing_enabled,
        :zoekt_search_enabled,
        :zoekt_indexing_paused,
        :zoekt_auto_index_root_namespace,
        :zoekt_auto_delete_lost_nodes
      ]

      boolean_settings.each do |setting|
        expect(described_class::SETTINGS[setting][:type]).to eq(:boolean)
      end
    end

    it 'has numeric settings with correct type' do
      expect(described_class::SETTINGS[:zoekt_cpu_to_tasks_ratio][:type]).to eq(:float)
    end

    it 'defines input options for numeric settings' do
      expect(described_class::SETTINGS[:zoekt_cpu_to_tasks_ratio][:input_type]).to eq(:number_field)
      expect(described_class::SETTINGS[:zoekt_cpu_to_tasks_ratio][:input_options]).to include(step: 0.1)
    end
  end

  describe '.all_settings' do
    it 'returns all settings' do
      expect(described_class.all_settings).to eq(described_class::SETTINGS)
    end

    it 'returns a frozen hash' do
      expect(described_class.all_settings).to be_frozen
    end
  end

  describe '.boolean_settings' do
    it 'returns only boolean settings' do
      boolean_settings = described_class.boolean_settings

      expect(boolean_settings.keys).to contain_exactly(
        :zoekt_indexing_enabled,
        :zoekt_search_enabled,
        :zoekt_indexing_paused,
        :zoekt_auto_index_root_namespace,
        :zoekt_auto_delete_lost_nodes
      )

      boolean_settings.each_value do |config|
        expect(config[:type]).to eq(:boolean)
      end
    end
  end

  describe '.numeric_settings' do
    it 'returns only numeric settings' do
      numeric_settings = described_class.numeric_settings

      expect(numeric_settings.keys).to contain_exactly(
        :zoekt_cpu_to_tasks_ratio,
        :zoekt_rollout_batch_size
      )

      numeric_settings.each_value do |config|
        expect(config[:type]).to be_in([:float, :integer])
      end
    end
  end
end
