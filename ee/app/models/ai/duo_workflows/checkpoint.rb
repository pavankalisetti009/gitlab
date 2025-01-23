# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class Checkpoint < ::ApplicationRecord
      self.table_name = :duo_workflows_checkpoints

      belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'
      belongs_to :project

      validates :thread_ts, presence: true
      validates :checkpoint, presence: true
      validates :metadata, presence: true

      after_save :touch_workflow

      private

      def touch_workflow
        workflow.touch
      end
    end
  end
end
