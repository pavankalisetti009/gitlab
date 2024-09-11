# frozen_string_literal: true

module EE
  module Gitlab
    module Tracking
      module AiTracking
        extend ::Gitlab::Utils::Override

        POSSIBLE_MODELS = [Ai::CodeSuggestionEvent, Ai::DuoChatEvent].freeze

        override :track_event
        def track_event(event_name, context_hash = {})
          return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

          matched_model = POSSIBLE_MODELS.detect { |model| model.related_event?(event_name) }

          return unless matched_model

          event = matched_model.new(context_hash.with_indifferent_access.merge(event: event_name))

          event.store_to_clickhouse
        end
      end
    end
  end
end
