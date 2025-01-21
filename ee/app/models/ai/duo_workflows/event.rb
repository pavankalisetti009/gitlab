# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class Event < ::ApplicationRecord
      self.table_name = :duo_workflows_events

      belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'
      belongs_to :project

      validates :event_type, presence: true
      validates :event_status, presence: true

      enum event_type: { pause: 0, resume: 1, stop: 2, message: 3, response: 4, require_input: 5 }
      enum event_status: { queued: 0, delivered: 1 }

      scope :queued, -> { where(event_status: event_statuses[:queued]) }
      scope :delivered, -> { where(event_status: event_statuses[:delivered]) }
    end
  end
end
