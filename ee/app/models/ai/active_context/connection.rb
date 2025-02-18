# frozen_string_literal: true

module Ai
  module ActiveContext
    class Connection < ApplicationRecord
      self.table_name = :ai_active_context_connections

      encrypts :options

      validates :name, presence: true, length: { maximum: 255 }, uniqueness: true
      validates :adapter_class, presence: true, length: { maximum: 255 }
      validates :prefix, length: { maximum: 255 }, allow_nil: true
      validates :active, inclusion: { in: [true, false] }
      validates :options, presence: true
      validate :validate_options
      validates_uniqueness_of :active, conditions: -> { where(active: true) }, if: :active

      scope :active, -> { where(active: true) }

      private

      def validate_options
        return if options.is_a?(Hash)

        errors.add(:options, 'must be a hash')
      end
    end
  end
end
