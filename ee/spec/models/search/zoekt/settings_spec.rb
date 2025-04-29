# frozen_string_literal: true

require 'spec_helper'

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
        :zoekt_auto_delete_lost_nodes,
        :zoekt_cache_response
      )

      boolean_settings.each_value do |config|
        expect(config[:type]).to eq(:boolean)
      end
    end
  end

  describe '.input_settings' do
    it 'returns only input_settings settings' do
      input_settings = described_class.input_settings

      expected_list = %i[zoekt_cpu_to_tasks_ratio zoekt_rollout_batch_size zoekt_rollout_retry_interval]
      expect(input_settings.keys).to match_array(expected_list)

      input_settings.each_value do |config|
        expect(config[:type]).to be_in(%i[float integer text])
      end
    end
  end

  describe '.rollout_retry_interval' do
    let_it_be(:_) { create(:application_setting) }

    before do
      stub_ee_application_setting(zoekt_rollout_retry_interval: interval)
    end

    using RSpec::Parameterized::TableSyntax

    where(:interval, :duration_interval) do
      '0'   | nil # nil for 0 means retry is disabled
      '1x'  | 1.day # default for invalid interval
      '5m'  | 5.minutes
      '2h'  | 2.hours
      '3d'  | 3.days
    end

    with_them do
      it 'returns the correct duration_interval' do
        expect(described_class.rollout_retry_interval).to eq(duration_interval)
      end
    end
  end
end
