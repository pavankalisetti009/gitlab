# frozen_string_literal: true

module EE
  module Gitlab
    module Tracking
      module AiTracking
        extend ::Gitlab::Utils::Override

        POSSIBLE_MODELS = [Ai::CodeSuggestionEvent, Ai::DuoChatEvent].freeze

        override :track_event
        def track_event(event_name, context_hash = {})
          event = build_event_model(event_name, context_hash)

          return unless event

          store_to_clickhouse(event)
          store_to_postgres(event)
        end

        private

        def build_event_model(event_name, context_hash = {})
          matched_model = POSSIBLE_MODELS.detect { |model| model.related_event?(event_name) }

          return unless matched_model

          matched_model.new(context_hash.with_indifferent_access.merge(event: event_name))
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
