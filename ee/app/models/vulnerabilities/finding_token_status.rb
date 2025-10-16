# frozen_string_literal: true

module Vulnerabilities
  class FindingTokenStatus < ::SecApplicationRecord
    include Gitlab::InternalEventsTracking

    self.table_name = 'secret_detection_token_statuses'
    self.primary_key = 'vulnerability_occurrence_id'

    enum :status, Security::TokenStatus::STATUSES, prefix: true

    belongs_to :finding,
      class_name: 'Vulnerabilities::Finding',
      foreign_key: 'vulnerability_occurrence_id',
      inverse_of: :finding_token_status

    belongs_to :project

    validates :status, presence: true
    validates :project_id, presence: true

    # Ensure the project_id is always set from the finding
    before_validation :set_project_id, on: :create, if: -> { project_id.nil? && finding.present? }

    scope :with_vulnerability_occurrence_ids, ->(ids) { where(vulnerability_occurrence_id: ids) }

    after_create :track_token_verification

    private

    def track_token_verification
      return unless finding&.token_type

      track_internal_event(
        'secret_detection_token_verified',
        project: finding.project,
        namespace: finding.project&.namespace,
        additional_properties: {
          label: finding.token_type
        }
      )
    rescue StandardError => e
      Gitlab::ErrorTracking.track_exception(e, finding_id: finding&.id)
    end

    def set_project_id
      self.project_id = finding.project_id
    end
  end
end
