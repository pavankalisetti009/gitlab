# frozen_string_literal: true

FactoryBot.define do
  factory :security_finding_enrichment, class: 'Security::FindingEnrichment' do
    association :project
    association :cve_enrichment, factory: :pm_cve_enrichment
    cve { cve_enrichment.cve }
    finding_uuid { build(:security_finding).uuid }
  end
end
