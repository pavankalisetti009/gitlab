# frozen_string_literal: true

module Ai
  module UsageEvent
    extend ActiveSupport::Concern
    include ClickHouseModel

    included do
      class << self
        def related_event?(event_name)
          events.key?(event_name)
        end

        def payload_attributes
          schema_validator = validators_on(:payload).detect { |v| v.is_a?(JsonSchemaValidator) }
          schema_validator.schema.value['properties'].keys
        end
      end

      before_validation :floor_timestamp
    end

    PERMITTED_ATTRIBUTES = %w[user user_id organization organization_id personal_namespace_id namespace_path timestamp
      event].freeze

    def to_clickhouse_csv_row
      {
        event: self.class.events[event],
        timestamp: timestamp.to_f,
        user_id: user&.id
      }
    end

    # Default to empty hash if payload is empty
    def payload
      super || {}
    end

    private

    def floor_timestamp
      # we floor to 3 digits here to match current JSON rounding used in Write Buffers.
      # That creates consistency between PG and CH until https://gitlab.com/gitlab-org/gitlab/-/issues/527129
      # is resolved
      self.timestamp = timestamp&.floor(3)
    end
  end
end
