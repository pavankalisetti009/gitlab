# frozen_string_literal: true

module Ai
  module UsageEvent
    extend ActiveSupport::Concern
    include ClickHouseModel

    included do
      class << self
        def related_event?(event_name)
          event_name.in?(const_get(:EVENTS, false))
        end
      end
    end

    REQUIRED_ATTRIBUTES = %w[user user_id organization organization_id namespace_path timestamp event].freeze

    def initialize(attributes = {})
      hash = attributes.with_indifferent_access
      required_attributes = hash.slice(*::Ai::UsageEvent::REQUIRED_ATTRIBUTES)
      payload_attributes = (hash[:payload] || {}).merge(hash.slice(*self.class::PAYLOAD_ATTRIBUTES))

      super(required_attributes.merge(payload: payload_attributes))
    end

    def to_clickhouse_csv_row
      {
        event: self.class::EVENTS[event],
        timestamp: timestamp.to_f,
        user_id: user&.id
      }
    end
  end
end
