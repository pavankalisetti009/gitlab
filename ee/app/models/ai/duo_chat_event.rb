# frozen_string_literal: true

module Ai
  class DuoChatEvent
    include ActiveModel::Model
    include ActiveModel::Attributes
    include UsageEvent

    self.clickhouse_table_name = 'duo_chat_events'

    EVENTS = {
      'request_duo_chat_response' => 1
    }.freeze

    PAYLOAD_ATTRIBUTES = [].freeze

    attribute :user
    attribute :event, :string
    attribute :timestamp, :datetime, default: -> { DateTime.current }
    attribute :payload

    validates :event, inclusion: { in: EVENTS.keys }
    validates :user, presence: true
    validates :timestamp, presence: true
  end
end
