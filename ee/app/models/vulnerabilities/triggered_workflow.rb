# frozen_string_literal: true

module Vulnerabilities
  class TriggeredWorkflow < ::SecApplicationRecord
    self.table_name = 'vulnerability_triggered_workflows'

    belongs_to :vulnerability_occurrence, class_name: 'Vulnerabilities::Finding'
    belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'

    validates_presence_of :vulnerability_occurrence, :workflow
    validates :workflow_name, presence: true

    before_validation :assign_project_id

    WORKFLOW_NAMES = {
      sast_fp_detection: 0,
      resolve_sast_vulnerability: 1
    }.freeze

    enum :workflow_name, WORKFLOW_NAMES

    private

    def assign_project_id
      self.project_id ||= vulnerability_occurrence&.project_id
    end
  end
end
