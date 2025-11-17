# frozen_string_literal: true
module Vulnerabilities
  class MergeRequestLink < ::SecApplicationRecord
    include EachBatch

    MAX_MERGE_REQUEST_LINKS_PER_VULNERABILITY = 100

    self.table_name = 'vulnerability_merge_request_links'

    belongs_to :vulnerability
    belongs_to :merge_request
    belongs_to :vulnerability_occurrence, optional: true, class_name: 'Vulnerabilities::Finding'

    has_one :author, through: :merge_request, class_name: 'User'

    validates :vulnerability, :merge_request, presence: true
    validates :merge_request_id,
      uniqueness: { scope: :vulnerability_id, message: N_('is already linked to this vulnerability') }
    validates :readiness_score, inclusion: { in: 0.0..1.0 }, numericality: true, allow_nil: true

    scope :by_finding_uuids, ->(uuids) do
      joins(vulnerability: [:findings]).where(vulnerability: {
        vulnerability_occurrences: { uuid: uuids }
      })
    end
    scope :with_vulnerability_findings, -> { includes(vulnerability: [:findings]) }
    scope :with_merge_request, -> { preload(:merge_request) }
    scope :by_vulnerability, ->(values) { where(vulnerability_id: values) }

    def self.count_for_vulnerability(vulnerability)
      where(vulnerability: vulnerability).count
    end

    def self.limit_exceeded_for_vulnerability?(vulnerability)
      count_for_vulnerability(vulnerability) >= MAX_MERGE_REQUEST_LINKS_PER_VULNERABILITY
    end

    def self.find_by_vulnerability_and_merge_request(vulnerability, merge_request)
      find_by(vulnerability: vulnerability, merge_request: merge_request)
    end
  end
end
