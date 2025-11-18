# frozen_string_literal: true

module Vulnerabilities
  class TriggeredWorkflow < ::SecApplicationRecord
    self.table_name = 'vulnerability_triggered_workflows'

    belongs_to :vulnerability_occurrence, class_name: 'Vulnerabilities::Finding'
    belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'

    validates_presence_of :vulnerability_occurrence, :workflow
    validates :workflow_name, presence: true
    validate :vulnerability_workflow_belongs_to_same_project

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

    def vulnerability_workflow_belongs_to_same_project
      return unless vulnerability_occurrence
      return unless workflow

      return if vulnerability_occurrence.project_id == workflow.project_id

      errors.add(:workflow, _("must belong to the same project as the vulnerability"))
    end
  end
end
