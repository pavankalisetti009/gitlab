# frozen_string_literal: true

module Ai
  module ActiveContext
    class Migration < ApplicationRecord
      self.table_name = :ai_active_context_migrations

      attribute :retries_left, default: 3

      enum status: {
        pending: 0,
        in_progress: 1,
        completed: 10,
        failed: 255
      }

      belongs_to :connection, class_name: 'Ai::ActiveContext::Connection'

      validates :version, presence: true, format: { with: /\A\d{14}\z/, message: 'must be a 14-digit timestamp' }
      validates :version, uniqueness: { scope: :connection_id }
      validates :status, presence: true
      validates :retries_left, numericality: { greater_than_or_equal_to: 0 }
      validate :validate_zero_retries_left, if: -> { retries_left == 0 }

      private

      def validate_zero_retries_left
        errors.add(:retries_left, 'can only be 0 when status is failed') unless failed?
      end
    end
  end
end
