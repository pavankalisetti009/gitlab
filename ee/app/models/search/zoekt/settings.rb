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
          label: -> { _('Batch size of namespaces for initial indexing') },
          input_type: :number_field
        }
      }.freeze

      def self.all_settings
        SETTINGS
      end

      def self.boolean_settings
        SETTINGS.select { |_, config| config[:type] == :boolean }
      end

      def self.numeric_settings
        type_values = [:float, :integer]
        SETTINGS.select { |_, config| type_values.include?(config[:type]) }
      end
    end
  end
end
