# frozen_string_literal: true

module Ai
  class CodeSuggestionEvent < ApplicationRecord
    include EachBatch
    include UsageEvent

    self.table_name = "ai_code_suggestion_events"
    self.clickhouse_table_name = "code_suggestion_events"

    populate_sharding_key(:organization_id) { Gitlab::Current::Organization.new(user: user).organization&.id }

    enum :event, {
      code_suggestions_requested: 1, # old data https://gitlab.com/gitlab-org/gitlab/-/issues/462809
      code_suggestion_shown_in_ide: 2,
      code_suggestion_accepted_in_ide: 3,
      code_suggestion_rejected_in_ide: 4,
      code_suggestion_direct_access_token_refresh: 5 # old data https://gitlab.com/gitlab-org/gitlab/-/issues/462809
    }

    belongs_to :organization, class_name: 'Organizations::Organization'

    validates :organization_id, presence: true

    def to_clickhouse_csv_row
      super.merge({
        unique_tracking_id: payload['unique_tracking_id'],
        suggestion_size: payload['suggestion_size'],
        language: payload['language'],
        branch_name: payload['branch_name']
      })
    end
  end
end
