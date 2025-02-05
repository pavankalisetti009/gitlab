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

    PERMITTED_ATTRIBUTES = %w[user user_id organization organization_id personal_namespace_id namespace_path timestamp
      event].freeze

    def to_clickhouse_csv_row
      {
        event: self.class::EVENTS[event],
        timestamp: timestamp.to_f,
        user_id: user&.id
      }
    end
  end
end
