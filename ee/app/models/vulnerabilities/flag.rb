# frozen_string_literal: true

module Vulnerabilities
  class Flag < ::SecApplicationRecord
    self.table_name = 'vulnerability_flags'

    belongs_to :finding, class_name: 'Vulnerabilities::Finding', foreign_key: 'vulnerability_occurrence_id', inverse_of: :vulnerability_flags, optional: false
    FALSE_POSITIVE_DETECTION_STATUSES = {
      not_started: 0,
      in_progress: 1,
      detected_as_fp: 2,
      detected_as_not_fp: 3,
      failed: 4
    }.freeze

    AI_SAST_FP_DETECTION_ORIGIN = 'ai_sast_fp_detection'

    belongs_to :workflow, class_name: '::Ai::DuoWorkflows::Workflow', optional: true

    validates :origin, length: { maximum: 255 }
    validates :description, length: { maximum: 100000 }
    validates :flag_type, presence: true, uniqueness: { scope: [:vulnerability_occurrence_id, :origin] }
    validates :confidence_score, inclusion: { in: 0.0..1.0 }

    enum :flag_type, {
      false_positive: 0
    }

    enum :status, FALSE_POSITIVE_DETECTION_STATUSES
    scope :by_finding_id, ->(finding_ids) { where(finding: finding_ids) }

    after_commit :trigger_resolution_workflow, on: [:create, :update], if: :should_trigger_resolution_workflow?

    scope :with_associations, -> do
      includes(
        finding: [
          :project,
          { vulnerability: [:group, :author, :project] }
        ]
      )
    end

    def initialize(attributes)
      attributes = attributes.to_h if attributes.respond_to?(:to_h)
      super(attributes)
    end

    private

    def trigger_resolution_workflow
      ::Vulnerabilities::TriggerResolutionWorkflowWorker.perform_async(id)
    end

    def should_trigger_resolution_workflow?
      return false unless origin == AI_SAST_FP_DETECTION_ORIGIN
      return false unless confidence_score < ::Vulnerabilities::TriggerResolutionWorkflowWorker::CONFIDENCE_THRESHOLD
      return false unless ::Feature.enabled?(:enable_vulnerability_resolution, finding.project.root_ancestor)

      # On create, always trigger if conditions above are met
      return true if saved_change_to_id?

      # On update, only trigger if relevant fields changed
      saved_change_to_confidence_score? || saved_change_to_origin?
    end
  end
end
