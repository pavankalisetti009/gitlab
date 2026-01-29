# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::FindingMap, feature_category: :vulnerability_management do
  let_it_be(:pipeline) { build_stubbed(:ci_pipeline) }
  let_it_be(:tracked_context) { build_stubbed(:security_project_tracked_context, :tracked) }

  let(:security_finding) { build(:security_finding) }
  let(:identifier) { build(:ci_reports_security_identifier) }
  let(:report_finding) { build(:ci_reports_security_finding, identifiers: [identifier]) }
  let(:finding_map) do
    described_class.new(pipeline, tracked_context, security_finding, report_finding)
  end

  describe 'delegations' do
    subject { finding_map }

    it { is_expected.to delegate_method(:uuid).to(:security_finding) }
    it { is_expected.to delegate_method(:scanner_id).to(:security_finding) }
    it { is_expected.to delegate_method(:severity).to(:security_finding) }
    it { is_expected.to delegate_method(:project).to(:pipeline) }
    it { is_expected.to delegate_method(:evidence).to(:report_finding) }
  end

  describe '#tracked_context' do
    it 'returns the tracked context' do
      expect(finding_map.tracked_context).to eq(tracked_context)
    end
  end

  describe '#identifiers' do
    subject { finding_map.identifiers }

    it { is_expected.to eq([identifier]) }
  end

  describe '#set_identifier_ids_by' do
    let(:identifiers_map) { { identifier.fingerprint => 1 } }

    subject(:set_identifier_ids) { finding_map.set_identifier_ids_by(identifiers_map) }

    it 'changes the identifier_ids of the finding_map' do
      expect { set_identifier_ids }.to change { finding_map.identifier_ids }.from([]).to([1])
    end
  end

  describe '#context_aware_uuid' do
    subject(:uuid) { finding_map.context_aware_uuid }

    it 'generates a context-aware UUID using VulnerabilityUUID.generate_v2' do
      expected_uuid = ::Security::VulnerabilityUUID.generate_v2(
        report_type: report_finding.report_type,
        primary_identifier_fingerprint: identifier.fingerprint,
        location_fingerprint: report_finding.location.fingerprint,
        project_id: pipeline.project_id,
        context_id: tracked_context.id
      )

      expect(uuid).to eq(expected_uuid)
    end

    context 'when tracked context is nil' do
      let(:finding_map) { described_class.new(pipeline, nil, security_finding, report_finding) }

      it 'returns nil' do
        expect(uuid).to be_nil
      end
    end

    context 'when identifiers are empty' do
      let(:report_finding) { build(:ci_reports_security_finding, identifiers: []) }

      it 'generates a UUID with nil primary_identifier_fingerprint' do
        expected_uuid = ::Security::VulnerabilityUUID.generate_v2(
          report_type: report_finding.report_type,
          primary_identifier_fingerprint: nil,
          location_fingerprint: report_finding.location.fingerprint,
          project_id: pipeline.project_id,
          context_id: tracked_context.id
        )

        expect(uuid).to eq(expected_uuid)
      end
    end
  end

  describe '#to_hash' do
    let(:expected_new_uuid) do
      ::Security::VulnerabilityUUID.generate_v2(
        report_type: report_finding.report_type,
        primary_identifier_fingerprint: identifier.fingerprint,
        location_fingerprint: report_finding.location.fingerprint,
        project_id: pipeline.project_id,
        context_id: tracked_context.id
      )
    end

    let(:expected_hash) do
      {
        uuid: security_finding.uuid,
        new_uuid: expected_new_uuid,
        security_project_tracked_context_id: tracked_context.id,
        scanner_id: security_finding.scanner_id,
        primary_identifier_id: nil,
        location_fingerprint: report_finding.location.fingerprint,
        name: 'Cipher with no integrity',
        report_type: :sast,
        severity: :high,
        metadata_version: 'sast:1.0',
        details: {},
        raw_metadata: report_finding.raw_metadata,
        description: 'The cipher does not provide data integrity update 1',
        solution: 'GCM mode introduces an HMAC into the resulting encrypted data, providing integrity of the result.',
        location: {
          "class" => "com.gitlab.security_products.tests.App",
          "end_line" => 29,
          "file" => "maven/src/main/java/com/gitlab/security_products/tests/App.java",
          "method" => "insecureCypher",
          "start_line" => 29
        },
        project_id: pipeline.project_id,
        initial_pipeline_id: pipeline.id,
        latest_pipeline_id: pipeline.id
      }
    end

    subject(:hash) { finding_map.to_hash }

    it { is_expected.to eq(expected_hash) }

    context 'when tracked context is nil' do
      let(:finding_map) { described_class.new(pipeline, nil, security_finding, report_finding) }

      it 'returns nil for security_project_tracked_context_id' do
        expect(hash[:security_project_tracked_context_id]).to be_nil
      end

      it 'returns nil for new_uuid' do
        expect(hash[:new_uuid]).to be_nil
      end
    end

    context 'when location_data is a valid JSON string' do
      let(:location_hash) { { "file" => "test.rb", "line" => 10 } }
      let(:report_finding) do
        build(
          :ci_reports_security_finding,
          identifiers: [identifier],
          original_data: { 'location' => location_hash.to_json }
        )
      end

      it 'parses the JSON string to a hash' do
        expect(finding_map.to_hash[:location]).to eq(location_hash)
      end
    end

    context 'when location_data is an invalid JSON string' do
      let(:report_finding) do
        build(:ci_reports_security_finding,
          identifiers: [identifier],
          original_data: { 'location' => 'invalid json{' })
      end

      it 'returns an empty hash' do
        expect(finding_map.to_hash[:location]).to eq({})
      end
    end

    context 'when location_data is not a hash or string' do
      let(:report_finding) do
        build(:ci_reports_security_finding,
          identifiers: [identifier],
          original_data: { 'location' => 123 })
      end

      it 'returns an empty hash' do
        expect(finding_map.to_hash[:location]).to eq({})
      end
    end

    context 'when location_data is a string that parses to a non-Hash value' do
      let(:report_finding) do
        build(:ci_reports_security_finding,
          identifiers: [identifier],
          original_data: { 'location' => '123' })
      end

      it 'returns an empty hash' do
        expect(finding_map.to_hash[:location]).to eq({})
      end
    end
  end
end
