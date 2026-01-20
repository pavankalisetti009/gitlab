# frozen_string_literal: true

RSpec.shared_examples 'CVE enrichment filters model spec' do
  context 'when filtering by known_exploited' do
    it 'returns records with known exploits when known_exploited is true' do
      expect(described_class.with_cve_enrichment_filters(known_exploited: true)).to contain_exactly(
        record_with_enrichment
      )
    end

    it 'returns none when known_exploited is false (filter not applied)' do
      expect(described_class.with_cve_enrichment_filters(known_exploited: false)).to be_empty
    end
  end

  context 'when filtering by epss_score' do
    it 'returns records with EPSS score greater than threshold' do
      expect(described_class.with_cve_enrichment_filters(epss_operator: :greater_than, epss_value: 0.5))
        .to contain_exactly(record_with_enrichment)
    end

    it 'returns records with EPSS score greater than or equal to threshold' do
      expect(described_class.with_cve_enrichment_filters(epss_operator: :greater_than_or_equal_to, epss_value: 0.75))
        .to contain_exactly(record_with_enrichment)
    end

    it 'returns records with EPSS score less than threshold' do
      expect(described_class.with_cve_enrichment_filters(epss_operator: :less_than, epss_value: 0.5))
        .to contain_exactly(record_with_enrichment_no_exploit)
    end

    it 'returns records with EPSS score less than or equal to threshold' do
      expect(described_class.with_cve_enrichment_filters(epss_operator: :less_than_or_equal_to, epss_value: 0.75))
        .to contain_exactly(record_with_enrichment, record_with_enrichment_no_exploit)
    end

    it 'returns empty when no records match' do
      expect(described_class.with_cve_enrichment_filters(epss_operator: :greater_than, epss_value: 0.9)).to be_empty
    end
  end

  context 'when filtering by both known_exploited and epss_score' do
    it 'returns records matching both criteria' do
      expect(described_class.with_cve_enrichment_filters(
        known_exploited: true,
        epss_operator: :greater_than,
        epss_value: 0.5
      )).to contain_exactly(record_with_enrichment)
    end

    it 'filters by epss score only when known_exploited false' do
      expect(described_class.with_cve_enrichment_filters(
        known_exploited: false,
        epss_operator: :greater_than,
        epss_value: 0.2
      )).to contain_exactly(record_with_enrichment, record_with_enrichment_no_exploit)
    end
  end

  context 'when no filters are provided' do
    it 'returns none' do
      expect(described_class.with_cve_enrichment_filters).to eq(described_class.none)
    end
  end

  context 'when filtering by include_findings_with_unenriched_cves' do
    it 'returns records with unenriched CVEs' do
      expect(described_class.with_cve_enrichment_filters(include_findings_with_unenriched_cves: true))
        .to contain_exactly(record_with_unenriched_cves)
    end
  end

  context 'when combining include_findings_with_unenriched_cves with other CVE filters' do
    it 'returns records matching either the enrichment filters or unenriched findings' do
      expect(described_class.with_cve_enrichment_filters(
        include_findings_with_unenriched_cves: true,
        known_exploited: true,
        epss_operator: :greater_than,
        epss_value: 0.5
      )).to contain_exactly(record_with_unenriched_cves, record_with_enrichment)
    end
  end

  context 'when include_findings_with_unenriched_cves is false' do
    it 'does not filter by enrichment data availability' do
      expect(described_class.with_cve_enrichment_filters(include_findings_with_unenriched_cves: false))
        .to eq(described_class.none)
    end

    context 'when combined with other CVE filters' do
      it 'applies only the other filters' do
        expect(described_class.with_cve_enrichment_filters(
          include_findings_with_unenriched_cves: false,
          known_exploited: true
        )).to contain_exactly(record_with_enrichment)
      end
    end
  end
end
