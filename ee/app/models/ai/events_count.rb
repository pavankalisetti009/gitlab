# frozen_string_literal: true

module Ai
  class EventsCount < ApplicationRecord
    include PartitionedTable

    self.table_name = "ai_events_counts"

    # Ensure ActiveRecord generates queries correctly for partitioned table.
    self.primary_key = :id

    partitioned_by :events_date, strategy: :monthly, retain_for: 3.months

    enum :event, Ai::UsageEvent.events

    validates :user_id, :organization_id, :event, :events_date, :total_occurrences, presence: true
    validates :total_occurrences, numericality: { greater_than_or_equal_to: 0 }

    belongs_to :user
    belongs_to :namespace, optional: true
    belongs_to :organization, class_name: 'Organizations::Organization'
  end
end
