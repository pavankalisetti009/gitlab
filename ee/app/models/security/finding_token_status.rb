# frozen_string_literal: true

module Security
  class FindingTokenStatus < ::SecApplicationRecord
    include Gitlab::InternalEventsTracking

    self.table_name = 'security_finding_token_statuses'
    self.primary_key = 'security_finding_id'

    enum :status, Security::TokenStatus::STATUSES, prefix: true

    belongs_to :security_finding,
      class_name: 'Security::Finding',
      foreign_key: 'security_finding_id', # rubocop:disable Rails/RedundantForeignKey -- explicit fk required for spec matcher
      inverse_of: :token_status

    belongs_to :project

    validates :status, presence: true
    validates :project_id, presence: true

    before_validation :set_project_id, on: :create, if: -> { project_id.nil? && security_finding.present? }

    scope :with_security_finding_ids, ->(ids) { where(security_finding_id: ids) }
    scope :stale, -> { where(created_at: ...Security::Scan.stale_after) }

    after_create :track_token_verification

    private

    def set_project_id
      self.project_id = security_finding.project.id
    end

    def track_token_verification
      return unless security_finding&.token_type

      track_internal_event(
        'secret_detection_token_verified',
        project: security_finding.project,
        namespace: security_finding.project&.namespace,
        additional_properties: {
          label: security_finding.token_type
        }
      )
    rescue StandardError => e
      Gitlab::ErrorTracking.track_exception(e, finding_id: security_finding&.id)
    end
  end
end
