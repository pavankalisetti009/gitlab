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

    belongs_to :vulnerability_finding,
      class_name: 'Vulnerabilities::Finding',
      inverse_of: :security_finding_enrichments,
      primary_key: 'uuid',
      foreign_key: 'finding_uuid',
      optional: true

    belongs_to :cve_enrichment,
      class_name: 'PackageMetadata::CveEnrichment',
      inverse_of: :finding_enrichments,
      optional: true

    validates :finding_uuid, uniqueness: { scope: :cve }
    validates :cve, presence: true, format: { with: PackageMetadata::CveEnrichment::CVE_REGEX }

    scope :with_known_exploited, ->(known_exploited) { where(is_known_exploit: known_exploited) }

    scope :with_epss_score, ->(operator, value) do
      break none unless operator && value

      epss_score = arel_table[:epss_score]
      condition = case operator.to_sym
                  when :greater_than_or_equal_to then epss_score.gteq(value)
                  when :greater_than then epss_score.gt(value)
                  when :less_than_or_equal_to then epss_score.lteq(value)
                  when :less_than then epss_score.lt(value)
                  else
                    raise ArgumentError, "Unsupported operator: #{operator}"
                  end

      where(condition)
    end
  end
end
