# frozen_string_literal: true

module Ai
  class CodeSuggestionsUsage
    include ClickHouseModel

    self.clickhouse_table_name = 'code_suggestion_usages'

    EVENTS = {
      'code_suggestions_requested' => 1, # old data https://gitlab.com/gitlab-org/gitlab/-/issues/462809
      'code_suggestion_shown_in_ide' => 2,
      'code_suggestion_accepted_in_ide' => 3,
      'code_suggestion_rejected_in_ide' => 4,
      'code_suggestion_direct_access_token_refresh' => 5 # old data https://gitlab.com/gitlab-org/gitlab/-/issues/462809
    }.freeze

    attribute :user
    attribute :event, :string
    attribute :timestamp, :datetime, default: -> { DateTime.current }
    attribute :language, :string, default: -> { '' }
    attribute :suggestion_size, :integer, default: -> { 0 }
    attribute :unique_tracking_id, :string, default: -> { '' }

    validates :event, inclusion: { in: EVENTS.keys }
    validates :user, presence: true
    validates :timestamp, presence: true
    validates :suggestion_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    def to_clickhouse_csv_row
      {
        event: EVENTS[event],
        timestamp: timestamp.to_f,
        user_id: user&.id,
        unique_tracking_id: unique_tracking_id,
        suggestion_size: suggestion_size,
        language: language
      }
    end
  end
end
