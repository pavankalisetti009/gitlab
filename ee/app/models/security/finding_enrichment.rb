# frozen_string_literal: true

module Security
  class FindingEnrichment < SecApplicationRecord
    self.table_name = 'security_finding_enrichments'

    belongs_to :project, class_name: 'Project', optional: false
    belongs_to :security_finding,
      class_name: 'Security::Finding',
      inverse_of: :finding_enrichments,
      primary_key: 'uuid',
      foreign_key: 'finding_uuid',
      optional: false

    belongs_to :cve_enrichment,
      class_name: 'PackageMetadata::CveEnrichment',
      inverse_of: :finding_enrichments,
      optional: true

    validates :finding_uuid, uniqueness: { scope: :cve }
    validates :cve, presence: true, format: { with: PackageMetadata::CveEnrichment::CVE_REGEX }
  end
end
