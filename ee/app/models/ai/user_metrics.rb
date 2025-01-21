# frozen_string_literal: true

module Ai
  class UserMetrics < ApplicationRecord
    self.table_name = 'ai_user_metrics'

    belongs_to :user, optional: false
  end
end
