# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::FindingEnrichment, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:scan)    { create(:security_scan, project: project) }
  let_it_be(:security_finding) { create(:security_finding, scan: scan) }

  subject { build(:security_finding_enrichment, project: project, security_finding: security_finding) }

  describe 'associations' do
    it { is_expected.to belong_to(:project).class_name('Project').required }

    it 'belongs to security finding' do
      is_expected.to belong_to(:security_finding)
                      .class_name('Security::Finding')
                      .with_primary_key('uuid')
                      .with_foreign_key('finding_uuid')
                      .inverse_of(:finding_enrichments)
                      .required
    end

    it 'belongs to CVE enrichment' do
      is_expected.to belong_to(:cve_enrichment)
                      .class_name('PackageMetadata::CveEnrichment')
                      .inverse_of(:finding_enrichments)
                      .optional
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:cve) }
    it { is_expected.to validate_uniqueness_of(:finding_uuid).scoped_to(:cve).ignoring_case_sensitivity }

    describe 'cve format validation' do
      it { is_expected.to allow_value('CVE-2024-1234').for(:cve) }
      it { is_expected.to allow_value('CVE-2024-12345').for(:cve) }
      it { is_expected.to allow_value('CVE-2024-123456789012345').for(:cve) }
      it { is_expected.not_to allow_value('CVE-2024-123').for(:cve) }
      it { is_expected.not_to allow_value('CVE-24-1234').for(:cve) }
      it { is_expected.not_to allow_value('cve-2024-1234').for(:cve) }
      it { is_expected.not_to allow_value('2024-1234').for(:cve) }
      it { is_expected.not_to allow_value('CVE-2024-1234567890123456').for(:cve) }
    end
  end
end
