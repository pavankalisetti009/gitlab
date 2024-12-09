# frozen_string_literal: true

module EE
  module Gitlab
    module Tracking
      module AiTracking
        extend ::Gitlab::Utils::Override

        POSSIBLE_MODELS = [Ai::CodeSuggestionEvent, Ai::DuoChatEvent].freeze

        override :track_event
        def track_event(event_name, **context_hash)
          event = build_event_model(event_name, context_hash)

          return unless event

          store_to_clickhouse(event)
          store_to_postgres(event)
        end

        private

        def build_event_model(event_name, context_hash = {})
          matched_model = POSSIBLE_MODELS.detect { |model| model.related_event?(event_name) }
          return unless matched_model

          context_hash = context_hash.with_indifferent_access
          context_hash[:event] = event_name

          if ::Feature.enabled?(:move_ai_tracking_to_instrumentation_layer, context_hash[:user])
            context_hash = filter_attributes(context_hash, matched_model)
          end

          matched_model.new(context_hash)
        end

        def filter_attributes(hash, model)
          hash.select do |key, _value|
            key = key.to_s
            model.attribute_types.key?(key) || model.attribute_types.key?("#{key}_id")
          end
        end

        def store_to_clickhouse(event)
          return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

          event.store_to_clickhouse
        end

        def store_to_postgres(event)
          return unless ::Feature.enabled?(:code_suggestions_usage_events_in_pg) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- it's a derisk flag
          return unless event.respond_to?(:store_to_pg)

          event.store_to_pg
        end
      end
    end
  end
end
