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

    def initialize(attributes)
      attributes = attributes.to_h if attributes.respond_to?(:to_h)
      super(attributes)
    end
  end
end
