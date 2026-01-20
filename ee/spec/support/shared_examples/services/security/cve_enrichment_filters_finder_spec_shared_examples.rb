# frozen_string_literal: true

RSpec.shared_examples 'CVE enrichment filters finder spec' do
  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(security_policies_kev_filter: false)
    end

    let(:filter_params) do
      {
        enrichment_data_unavailable_action: 'block',
        known_exploited: true,
        epss_score: { operator: :greater_than_or_equal_to, value: 0.8 }
      }
    end

    it 'returns all records without applying CVE enrichment filters' do
      is_expected.to match_array(all_records)
    end

    it 'does not call with_cve_enrichment_filters' do
      expect(model_class).not_to receive(:with_cve_enrichment_filters)

      subject
    end
  end

  context 'when applying all CVE enrichment filters' do
    let(:filter_params) do
      {
        enrichment_data_unavailable_action: 'block',
        known_exploited: true,
        epss_score: { operator: :greater_than_or_equal_to, value: 0.8 }
      }
    end

    it 'returns matching and unenriched records' do
      is_expected.to contain_exactly(finding_with_enrichment, finding_with_unenriched_cve)
    end

    it 'calls with_cve_enrichment_filters with correct parameters' do
      expect(model_class).to receive(:with_cve_enrichment_filters).with(
        known_exploited: true,
        epss_operator: :greater_than_or_equal_to,
        epss_value: 0.8,
        include_findings_with_unenriched_cves: true
      ).and_call_original

      subject
    end
  end

  context 'when filtering by known_exploited' do
    context 'when known_exploited is true' do
      let(:filter_params) { { known_exploited: true } }

      it { is_expected.to contain_exactly(finding_with_enrichment) }
    end

    context 'when known_exploited is false' do
      let(:filter_params) { { known_exploited: false } }

      it { is_expected.to match_array(all_records) }
    end
  end

  context 'when filtering by epss_score' do
    {
      greater_than: [0.5, [:finding_with_enrichment]],
      greater_than_or_equal_to: [0.8, [:finding_with_enrichment]],
      less_than: [0.9, %i[finding_with_enrichment finding_with_enrichment_no_exploit]],
      less_than_or_equal_to: [0.8, %i[finding_with_enrichment finding_with_enrichment_no_exploit]]
    }.each do |operator, (value, expected)|
      context operator.to_s do
        let(:filter_params) { { epss_score: { operator: operator, value: value } } }

        it { is_expected.to match_array(expected.map { |f| send(f) }) }
      end
    end
  end

  context 'when combining known_exploited and epss_score' do
    let(:filter_params) do
      {
        known_exploited: true,
        epss_score: { operator: :greater_than_or_equal_to, value: 0.8 }
      }
    end

    it { is_expected.to contain_exactly(finding_with_enrichment) }
  end

  context 'when no records match' do
    let(:filter_params) { { epss_score: { operator: :greater_than, value: 0.9 } } }

    it { is_expected.to be_empty }
  end

  context 'when filters are invalid' do
    let(:filter_params) do
      { epss_score: { operator: :invalid_operator, value: 'not_a_number' } }
    end

    it { is_expected.to match_array(all_records) }
  end

  context 'when enrichment data is unavailable' do
    context 'when enrichment_data_unavailable_action is block' do
      let(:filter_params) { { enrichment_data_unavailable_action: 'block' } }

      it { is_expected.to contain_exactly(finding_with_unenriched_cve) }
    end

    context 'when enrichment_data_unavailable_action is ignore' do
      let(:filter_params) { { enrichment_data_unavailable_action: 'ignore' } }

      it { is_expected.to match_array(all_records) }
    end
  end

  context 'when including unenriched CVEs with other filters' do
    let(:filter_params) do
      {
        enrichment_data_unavailable_action: 'block',
        known_exploited: true,
        epss_score: { operator: :greater_than_or_equal_to, value: 0.8 }
      }
    end

    it 'returns matching and unenriched records' do
      is_expected.to contain_exactly(
        finding_with_enrichment,
        finding_with_unenriched_cve
      )
    end
  end
end
