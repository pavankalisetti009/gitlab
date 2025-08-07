# frozen_string_literal: true

module Ai
  class FlowTrigger < ApplicationRecord
    self.table_name = :ai_flow_triggers

    EVENT_TYPES = {
      mention: 0
    }.freeze

    belongs_to :project
    belongs_to :user

    validates :project, presence: true
    validates :user, presence: true
    validates :event_types, presence: true

    validates :description, length: { maximum: 255 }, presence: true
    validates :config_path, length: { maximum: 255 }

    validate :event_types_are_valid

    scope :with_ids, ->(ids) { where(id: ids) }

    private

    def event_types_are_valid
      return if event_types.blank?

      invalid_types = event_types - EVENT_TYPES.values
      return if invalid_types.empty?

      errors.add(:event_types, "contains invalid event types: #{invalid_types.join(', ')}")
    end
  end
end
