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
        :zoekt_lost_node_threshold,
        :zoekt_cpu_to_tasks_ratio,
        :zoekt_default_number_of_replicas
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
        :zoekt_auto_index_root_namespace
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
        :zoekt_cache_response
      )

      boolean_settings.each_value do |config|
        expect(config[:type]).to eq(:boolean)
      end
    end
  end

  describe '.input_settings' do
    it 'returns only input_settings settings' do
      expected_list = %i[
        zoekt_cpu_to_tasks_ratio zoekt_indexing_parallelism zoekt_rollout_batch_size zoekt_indexing_timeout
        zoekt_maximum_files zoekt_rollout_retry_interval zoekt_lost_node_threshold zoekt_default_number_of_replicas
      ]

      input_settings = described_class.input_settings

      expect(input_settings.keys).to match_array(expected_list)
      input_settings.each_value do |config|
        expect(config[:type]).to be_in(%i[float integer text])
      end
    end
  end

  describe '.parse_duration' do
    using RSpec::Parameterized::TableSyntax

    where(:setting_value, :default, :allow_disabled, :result) do
      '0'   | '1d'  | true  | nil # nil for 0 means disabled
      '1x'  | '1d'  | true  | 1.day # default for invalid interval
      '5m'  | '2d'  | true  | 5.minutes
      '2h'  | '3d'  | true  | 2.hours
      '3d'  | '4d'  | true  | 3.days
      '0'   | '1m'  | false | 1.minute
    end

    with_them do
      it 'parses the duration correctly' do
        expect(described_class.parse_duration(setting_value, default, allow_disabled: allow_disabled)).to eq(result)
      end
    end
  end

  describe '.indexing_timeout' do
    let_it_be(:_) { create(:application_setting) }

    context 'with various intervals' do
      before do
        stub_ee_application_setting(zoekt_indexing_timeout: interval)
      end

      using RSpec::Parameterized::TableSyntax

      where(:interval, :duration_interval) do
        '0'   | 30.minutes # default for invalid interval
        '1x'  | 30.minutes # default for invalid interval
        '5m'  | 5.minutes
        '2h'  | 2.hours
        '3d'  | 3.days
      end

      with_them do
        it 'returns the correct duration_interval' do
          expect(described_class.indexing_timeout).to eq(duration_interval)
        end
      end
    end

    context 'when delegated to parse_duration' do
      before do
        allow(ApplicationSetting).to receive_message_chain(:current, :zoekt_rollout_retry_interval).and_return('1d')
      end

      it 'calls parse_duration with correct arguments' do
        expect(described_class).to receive(:parse_duration)
                                     .with('1d', described_class::DEFAULT_ROLLOUT_RETRY_INTERVAL)

        described_class.rollout_retry_interval
      end
    end
  end

  describe '.rollout_retry_interval' do
    let_it_be(:_) { create(:application_setting) }

    context 'with various intervals' do
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

    context 'when delegated to parse_duration' do
      before do
        allow(ApplicationSetting).to receive_message_chain(:current, :zoekt_rollout_retry_interval).and_return('1d')
      end

      it 'calls parse_duration with correct arguments' do
        expect(described_class).to receive(:parse_duration)
          .with('1d', described_class::DEFAULT_ROLLOUT_RETRY_INTERVAL)

        described_class.rollout_retry_interval
      end
    end
  end

  describe '.lost_node_threshold' do
    let_it_be(:_) { create(:application_setting) }

    before do
      stub_ee_application_setting(zoekt_lost_node_threshold: interval)
    end

    context 'with various intervals' do
      using RSpec::Parameterized::TableSyntax

      where(:interval, :duration_interval) do
        '0'   | nil # nil for 0 means disabled
        '1x'  | 12.hours # default for invalid interval
        '5m'  | 5.minutes
        '2h'  | 2.hours
        '3d'  | 3.days
      end

      with_them do
        it 'returns the correct duration_interval' do
          expect(described_class.lost_node_threshold).to eq(duration_interval)
        end
      end
    end

    context 'when delegated to parse_duration' do
      let(:interval) { '1h' }

      it 'calls parse_duration with correct arguments' do
        expect(described_class).to receive(:parse_duration)
          .with('1h', described_class::DEFAULT_LOST_NODE_THRESHOLD)

        described_class.lost_node_threshold
      end
    end
  end

  describe 'FILTER_ADMIN_UI' do
    it 'is a callable lambda' do
      expect(described_class::FILTER_ADMIN_UI).to be_a(Proc)
    end

    it 'filters out settings with admin_ui set to false' do
      settings = {
        visible_setting: { admin_ui: true, type: :boolean },
        hidden_setting: { admin_ui: false, type: :boolean },
        default_setting: { type: :boolean }
      }

      filtered = described_class::FILTER_ADMIN_UI.call(settings)

      expect(filtered.keys).to contain_exactly(:visible_setting, :default_setting)
    end

    it 'keeps settings without admin_ui key' do
      settings = {
        setting_without_key: { type: :boolean },
        setting_with_true: { admin_ui: true, type: :boolean }
      }

      filtered = described_class::FILTER_ADMIN_UI.call(settings)

      expect(filtered.keys).to contain_exactly(:setting_without_key, :setting_with_true)
    end
  end

  describe '.boolean_settings_ui' do
    it 'returns only boolean settings visible in the UI' do
      boolean_ui_settings = described_class.boolean_settings_ui

      expect(boolean_ui_settings.keys).to contain_exactly(
        :zoekt_indexing_enabled,
        :zoekt_search_enabled,
        :zoekt_indexing_paused,
        :zoekt_auto_index_root_namespace,
        :zoekt_cache_response
      )

      boolean_ui_settings.each_value do |config|
        expect(config[:type]).to eq(:boolean)
        expect(config[:admin_ui]).not_to be(false)
      end
    end

    it 'is a subset of boolean_settings' do
      boolean_ui = described_class.boolean_settings_ui
      all_boolean = described_class.boolean_settings

      expect(all_boolean.keys).to include(*boolean_ui.keys)
    end

    it 'excludes settings with admin_ui explicitly set to false' do
      settings_with_admin_ui_false = described_class.boolean_settings.select do |_key, config|
        config[:admin_ui] == false
      end

      boolean_ui = described_class.boolean_settings_ui

      settings_with_admin_ui_false.each_key do |key|
        expect(boolean_ui).not_to have_key(key)
      end
    end
  end

  describe '.input_settings_ui' do
    it 'returns only input settings visible in the UI' do
      input_ui_settings = described_class.input_settings_ui

      expected_list = %i[
        zoekt_cpu_to_tasks_ratio zoekt_indexing_parallelism zoekt_rollout_batch_size zoekt_indexing_timeout
        zoekt_maximum_files zoekt_rollout_retry_interval zoekt_lost_node_threshold
      ]

      expect(input_ui_settings.keys).to match_array(expected_list)

      input_ui_settings.each_value do |config|
        expect(config[:type]).to be_in(%i[float integer text])
        expect(config[:admin_ui]).not_to be(false)
      end
    end

    it 'is a subset of input_settings' do
      input_ui = described_class.input_settings_ui
      all_input = described_class.input_settings

      expect(all_input.keys).to include(*input_ui.keys)
    end

    it 'excludes settings with admin_ui explicitly set to false' do
      settings_with_admin_ui_false = described_class.input_settings.select do |_key, config|
        config[:admin_ui] == false
      end

      input_ui = described_class.input_settings_ui

      settings_with_admin_ui_false.each_key do |key|
        expect(input_ui).not_to have_key(key)
      end
    end
  end
end
