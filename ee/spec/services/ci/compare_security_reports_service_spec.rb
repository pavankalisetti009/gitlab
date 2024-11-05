# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CompareSecurityReportsService, feature_category: :vulnerability_management do
  subject { service.execute(base_pipeline, head_pipeline) }

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { project.owner }
  let_it_be(:test_pipelines) do
    {
      default_base: create(:ee_ci_pipeline),
      with_dependency_scanning_report: create(:ee_ci_pipeline, :with_dependency_scanning_report, project: project),
      with_container_scanning_report: create(:ee_ci_pipeline, :with_container_scanning_report, project: project),
      with_dast_report: create(:ee_ci_pipeline, :with_dast_report, project: project),
      with_sast_report: create(:ee_ci_pipeline, :with_sast_report, project: project),
      with_secret_detection_report: create(:ee_ci_pipeline, :with_secret_detection_report, project: project),
      with_dependency_scanning_feature_branch: create(:ee_ci_pipeline, :with_dependency_scanning_feature_branch, project: project),
      with_container_scanning_feature_branch: create(:ee_ci_pipeline, :with_container_scanning_feature_branch, project: project),
      with_dast_feature_branch: create(:ee_ci_pipeline, :with_dast_feature_branch, project: project),
      with_sast_feature_branch: create(:ee_ci_pipeline, :with_sast_feature_branch, project: project),
      with_secret_detection_feature_branch: create(:ee_ci_pipeline, :with_secret_detection_feature_branch, project: project),
      with_corrupted_dependency_scanning_report: create(:ee_ci_pipeline, :with_corrupted_dependency_scanning_report, project: project),
      with_corrupted_container_scanning_report: create(:ee_ci_pipeline, :with_corrupted_container_scanning_report, project: project)
    }
  end

  let(:service) { described_class.new(project, current_user, report_type: scan_type.to_s) }

  def collect_ids(collection)
    collection.map { |t| t['identifiers'].first['external_id'] }
  end

  shared_examples_for 'serializes `found_by_pipeline` attribute' do
    let(:first_added_finding) { subject.dig(:data, 'added').first }
    let(:first_fixed_finding) { subject.dig(:data, 'fixed').first }

    it 'sets correct `found_by_pipeline` attribute' do
      expect(first_added_finding.dig('found_by_pipeline', 'iid')).to eq(head_pipeline.iid)
      expect(first_fixed_finding.dig('found_by_pipeline', 'iid')).to eq(base_pipeline.iid)
    end
  end

  shared_examples_for 'when only the head pipeline has a report' do
    let(:base_pipeline) { test_pipelines[:default_base] }
    let(:head_pipeline) { test_pipelines[:"with_#{scan_type}_report"] }

    it 'reports the new vulnerabilities, while not changing the counts of fixed vulnerabilities' do
      expect(subject[:status]).to eq(:parsed)
      expect(subject[:data]['added'].count).to eq(num_findings_in_fixture)
      expect(subject[:data]['fixed'].count).to eq(0)
    end
  end

  shared_examples_for 'when base and head pipelines have scanning reports' do
    let_it_be(:base_pipeline) { test_pipelines[:"with_#{scan_type}_report"] }
    let_it_be(:head_pipeline) { test_pipelines[:"with_#{scan_type}_feature_branch"] }
    let(:expected_payload_fields) do
      %w[create_vulnerability_feedback_issue_path create_vulnerability_feedback_merge_request_path
        create_vulnerability_feedback_dismissal_path create_vulnerability_feedback_issue_path]
    end

    it 'reports status as parsed' do
      expect(subject[:status]).to eq(:parsed)
    end

    it 'populates fields based on current_user' do
      payload = subject[:data]['added'].first
      expected_payload_fields.each { |f| expect(payload[f]).to be_present }
      expect(service.current_user).to eq(current_user)
    end

    it 'reports added vulnerability' do
      compare_keys = collect_ids(subject[:data]['added'])
      expect(compare_keys).to match_array(expected_added_keys)
    end

    it 'reports fixed dependency scanning vulnerabilities' do
      compare_keys = collect_ids(subject[:data]['fixed'])
      expect(compare_keys).to match_array(expected_fixed_keys)
    end
  end

  shared_examples_for 'when head pipeline has corrupted scanning reports' do
    let_it_be(:base_pipeline) { test_pipelines[:"with_corrupted_#{scan_type}_report"] }
    let_it_be(:head_pipeline) { test_pipelines[:"with_corrupted_#{scan_type}_report"] }

    it 'returns status and error message' do
      expect(subject[:status]).to eq(:error)
      expect(subject[:status_reason]).to include('JSON parsing failed')
    end

    it 'returns status and error message when pipeline is nil' do
      result = service.execute(nil, head_pipeline)

      expect(result[:status]).to eq(:error)
      expect(result[:status_reason]).to include('JSON parsing failed')
    end
  end

  describe '#execute' do
    where(vulnerability_finding_signatures: [true, false])
    with_them do
      before do
        stub_licensed_features(vulnerability_finding_signatures: vulnerability_finding_signatures)
        stub_licensed_features(security_dashboard: true, scan_type => true)
      end

      context 'with dependency_scanning' do
        let_it_be(:scan_type) { :dependency_scanning }

        it_behaves_like 'when only the head pipeline has a report' do
          let(:num_findings_in_fixture) { 4 }
        end

        it_behaves_like 'when base and head pipelines have scanning reports' do
          let(:expected_fixed_keys) { %w[06565b64-486d-4326-b906-890d9915804d] }
          let(:expected_added_keys) { %w[CVE-2017-5946] }
          it_behaves_like 'serializes `found_by_pipeline` attribute'
        end

        it_behaves_like 'when head pipeline has corrupted scanning reports'
      end

      context 'with container_scanning' do
        let_it_be(:scan_type) { :container_scanning }

        it_behaves_like 'when only the head pipeline has a report' do
          let(:num_findings_in_fixture) { 8 }
        end

        it_behaves_like 'when base and head pipelines have scanning reports' do
          let(:expected_fixed_keys) { %w[CVE-2017-16997 CVE-2017-18269 CVE-2018-1000001 CVE-2016-10228 CVE-2010-4052 CVE-2018-18520 CVE-2018-16869 CVE-2018-18311] }
          let(:expected_added_keys) { %w[CVE-2017-15650] }
          it_behaves_like 'serializes `found_by_pipeline` attribute'
        end

        it_behaves_like 'when head pipeline has corrupted scanning reports'
      end

      context 'with dast' do
        let_it_be(:scan_type) { :dast }

        it_behaves_like 'when only the head pipeline has a report' do
          let(:num_findings_in_fixture) { 20 }
        end

        it_behaves_like 'when base and head pipelines have scanning reports' do
          let(:expected_fixed_keys) { %w[10010 10027 10027 10027 10027 10054 10054 10096 10202 10202 10202 10202 20012 20012 20012 20012 90011 90033 90033] }
          let(:expected_added_keys) { %w[10027] }
          it_behaves_like 'serializes `found_by_pipeline` attribute'
        end
      end

      context 'with sast' do
        let_it_be(:scan_type) { :sast }

        it_behaves_like 'when only the head pipeline has a report' do
          let(:num_findings_in_fixture) { 5 }
        end

        it_behaves_like 'when base and head pipelines have scanning reports' do
          let(:expected_fixed_keys) { %w[CIPHER_INTEGRITY] }
          let(:expected_added_keys) { %w[ECB_MODE] }
          it_behaves_like 'serializes `found_by_pipeline` attribute'
        end
      end

      context 'with secret detection' do
        let_it_be(:scan_type) { :secret_detection }

        it_behaves_like 'when only the head pipeline has a report' do
          let(:num_findings_in_fixture) { 1 }
        end

        it_behaves_like 'when base and head pipelines have scanning reports' do
          let(:expected_added_keys) { %w[] }
          let(:expected_fixed_keys) { %w[AWS] }
          let(:expected_payload_fields) { [] }

          it 'returns nil for the "added" field' do
            expect(subject[:data]['added'].first).to be_nil
          end
        end
      end
    end
  end
end
