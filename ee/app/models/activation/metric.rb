# frozen_string_literal: true

module Activation
  class Metric < ApplicationRecord
    self.table_name = 'activation_metrics'

    belongs_to :user, optional: false
    belongs_to :namespace, optional: true

    validates :metric, presence: true
    validates :metric, uniqueness: { scope: [:user_id, :namespace_id] }

    enum :metric, {
      merged_mr: 0 # Example metric, to be used in follow-up MR
    }
  end
end
