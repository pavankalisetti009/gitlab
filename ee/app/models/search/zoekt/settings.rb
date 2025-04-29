# frozen_string_literal: true

module Search
  module Zoekt
    # Settings module that contains Zoekt-specific settings configuration.
    # This module serves as a single source of truth for all Zoekt settings,
    # their types, defaults, and human-readable labels.
    #
    # Settings defined here are automatically:
    # - Added to visible attributes in ApplicationSettingsHelper
    # - Used to generate form inputs in the admin interface
    # - Displayed in the InfoService output
    #
    # To add a new setting:
    # 1. Add it to the SETTINGS hash with appropriate configuration
    # 2. The setting will automatically appear in all relevant places
    module Settings
      DEFAULT_ROLLOUT_RETRY_INTERVAL = '1d'
      ROLLOUT_RETRY_DISABLED_VALUE = '0'
      ROLLOUT_RETRY_INTERVAL_REGEX = %r{\A(?:0|([1-9]\d*)([mhd]))\z}

      SETTINGS = {
        zoekt_indexing_enabled: {
          type: :boolean,
          default: false,
          label: -> { _('Enable indexing') }
        },
        zoekt_search_enabled: {
          type: :boolean,
          default: false,
          label: -> { _('Enable searching') }
        },
        zoekt_indexing_paused: {
          type: :boolean,
          default: false,
          label: -> { _('Pause indexing') }
        },
        zoekt_auto_index_root_namespace: {
          type: :boolean,
          default: false,
          label: -> { _('Index root namespaces automatically') }
        },
        zoekt_auto_delete_lost_nodes: {
          type: :boolean,
          default: true,
          label: -> {
            format(_("Delete offline nodes after %{label}"),
              label: ::Search::Zoekt::Node::LOST_DURATION_THRESHOLD.inspect)
          }
        },
        zoekt_cache_response: {
          type: :boolean,
          default: true,
          label: -> {
            format(_("Cache search results for %{label}"), label: ::Search::Zoekt::Cache.humanize_expires_in)
          }
        },
        zoekt_cpu_to_tasks_ratio: {
          type: :float,
          default: 1.0,
          label: -> { _('Indexing CPU to tasks multiplier') },
          input_type: :number_field,
          input_options: { step: 0.1 }
        },
        zoekt_rollout_batch_size: {
          type: :integer,
          default: 32,
          label: -> { _('Number of namespaces per indexing rollout') },
          input_type: :number_field
        },
        zoekt_rollout_retry_interval: {
          type: :text,
          default: DEFAULT_ROLLOUT_RETRY_INTERVAL,
          label: -> { _('Retry interval for failed namespaces') },
          input_options: {
            placeholder: format(
              N_("Must be in the following format: `30m`, `2h`, or `1d`. Set to `%{val}` for no retries."),
              val: ROLLOUT_RETRY_DISABLED_VALUE)
          },
          input_type: :text_field
        }
      }.freeze

      def self.all_settings
        SETTINGS
      end

      def self.boolean_settings
        SETTINGS.select { |_, config| config[:type] == :boolean }
      end

      def self.input_settings
        type_values = %i[float integer text]
        SETTINGS.select { |_, config| type_values.include?(config[:type]) }
      end

      def self.rollout_retry_interval
        return if ApplicationSetting.current.zoekt_rollout_retry_interval == ROLLOUT_RETRY_DISABLED_VALUE

        match = ApplicationSetting.current.zoekt_rollout_retry_interval.match(ROLLOUT_RETRY_INTERVAL_REGEX)
        match ||= DEFAULT_ROLLOUT_RETRY_INTERVAL.match(ROLLOUT_RETRY_INTERVAL_REGEX)

        value = match[1].to_i
        unit = match[2]

        case unit
        when 'm' then value.minute
        when 'h' then value.hour
        when 'd' then value.day
        end
      end
    end
  end
end
