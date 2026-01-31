# frozen_string_literal: true

module Security
  module Ascp
    class Scan < ::SecApplicationRecord
      self.table_name = 'ascp_scans'

      enum :scan_type, { full: 0, incremental: 1 }

      belongs_to :project
      belongs_to :base_scan, class_name: 'Security::Ascp::Scan', optional: true

      # Inverse relationships for entities created in this scan
      # These will be uncommented as the related tables are added in subsequent MRs
      # has_many :sinks, class_name: 'Security::Ascp::Sink',
      #          foreign_key: :introduced_in_scan_id, inverse_of: :introduced_in_scan
      # has_many :fixed_sinks, class_name: 'Security::Ascp::Sink',
      #          foreign_key: :fixed_in_scan_id, inverse_of: :fixed_in_scan
      has_many :components, class_name: 'Security::Ascp::Component', inverse_of: :scan
      has_many :security_contexts, class_name: 'Security::Ascp::SecurityContext', inverse_of: :scan

      validates :project, presence: true
      validates :scan_sequence, presence: true
      validates :commit_sha, presence: true
      validates :scan_sequence, uniqueness: { scope: :project_id }
      validates :base_scan_id, presence: true, if: :incremental?

      scope :by_project, ->(project_id) { where(project_id: project_id) }
      scope :full_scans, -> { full }
      scope :incremental_scans, -> { incremental }
      scope :ordered, -> { order(scan_sequence: :desc) }
      scope :latest, -> { ordered.limit(1) }
    end
  end
end
