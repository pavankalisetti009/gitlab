# frozen_string_literal: true

module Ai
  class CodeSuggestionEvent < ApplicationRecord
    include PartitionedTable

    self.table_name = "ai_code_suggestion_events"
    self.primary_key = :id

    partitioned_by :timestamp, strategy: :monthly

    EVENTS = {
      'code_suggestion_shown_in_ide' => 2,
      'code_suggestion_accepted_in_ide' => 3,
      'code_suggestion_rejected_in_ide' => 4
    }.freeze

    attribute :timestamp, :datetime, default: -> { DateTime.current }

    enum event: EVENTS

    belongs_to :user

    validates :user, :timestamp, :organization_id, presence: true
    validates :payload, json_schema: { filename: "code_suggestion_event" }

    before_validation :populate_organization_id

    private

    def populate_organization_id
      self.organization_id = user&.namespace&.organization_id
    end
  end
end
