# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PolicyViolationsDetectedAuditEventService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:policy_project) { create(:project, :repository) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: policy_project)
  end

  let_it_be_with_reload(:merge_request) do
    create(:merge_request, title: "Test MR", source_project: project, target_project: project)
  end

  let_it_be(:security_policy_name) { 'Test Policy' }
  let_it_be_with_reload(:security_policy) do
    create(:security_policy, :approval_policy,
      name: security_policy_name,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:uuid) { SecureRandom.uuid }
  let_it_be(:uuid_previous) { SecureRandom.uuid }

  let(:service) { described_class.new(merge_request) }

  def build_violation_details(policy, data, status = :failed)
    create(:scan_result_policy_violation, status, project: project, merge_request: merge_request,
      scan_result_policy_read: policy, approval_policy_rule: approval_policy_rule, violation_data: data)
  end

  def build_violation_with_error(policy, error, status = :failed, **extra_data)
    build_violation_details(policy, { 'errors' => [{ 'error' => error, **extra_data }] }, status)
  end

  describe '#execute' do
    subject(:execute_service) { service.execute }

    let(:audit_context) do
      {
        name: 'policy_violations_detected',
        author: merge_request.author,
        scope: project,
        target: merge_request,
        message: "#{violations_count} merge request approval policy violation(s) detected in merge request " \
          "with title 'Test MR'",
        additional_details: {
          merge_request_title: merge_request.title,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          source_branch: merge_request.source_branch,
          target_branch: merge_request.target_branch,
          project_id: project.id,
          project_name: project.name,
          project_full_path: project.full_path,
          violated_policies: [
            {
              policy_id: security_policy.id,
              policy_name: 'Test Policy',
              policy_type: 'approval_policy',
              security_orchestration_policy_configuration_id: policy_configuration.id,
              security_policy_management_project_id: policy_configuration.security_policy_management_project_id
            }
          ],
          violation_details: violation_details
        }
      }
    end

    shared_examples 'recording the audit event' do
      it 'records a policy_violations_detected audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

        execute_service
      end
    end

    shared_examples 'not recording the audit event' do
      it 'does not record a policy_violations_detected audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(anything)

        execute_service
      end
    end

    context 'when there are scan finding violations' do
      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
      end

      let_it_be(:policy) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: policy_configuration)
      end

      let_it_be(:approver_rule_policy) do
        create(:report_approver_rule, :scan_finding,
          name: security_policy_name,
          merge_request: merge_request,
          scan_result_policy_read: policy
        )
      end

      let_it_be(:pipeline) do
        create(:ee_ci_pipeline, :with_dependency_scanning_report, :success, project: project,
          ref: merge_request.source_branch, sha: merge_request.diff_head_sha,
          merge_requests_as_head_pipeline: [merge_request])
      end

      let_it_be(:policy_violation) do
        build_violation_details(policy,
          context: { pipeline_ids: [pipeline.id] },
          violations: { scan_finding: { uuids: { newly_detected: [uuid], previously_existing: [uuid_previous] } } }
        )
      end

      let_it_be(:ci_build) { pipeline.builds.first }
      let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }

      let_it_be(:new_security_finding) do
        pipeline_scan = create(:security_scan, :succeeded, build: ci_build, scan_type: 'dependency_scanning')
        create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner, severity: 'high',
          uuid: uuid, finding_data: { name: 'New Test Finding', location: { file: '.env', start_line: 3 } })
      end

      let_it_be(:existing_vulnerability_finding) do
        create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
          uuid: uuid_previous, name: 'Existing AWS API key', severity: :critical)
      end

      let(:expected_new_finding_json) do
        {
          'name' => 'New Test Finding',
          'report_type' => 'dependency_scanning',
          'severity' => 'high',
          'location' => new_security_finding.location.as_json,
          'path' => new_security_finding.present.blob_url
        }
      end

      let(:expected_existing_finding_json) do
        {
          'name' => 'AWS API key',
          'report_type' => 'secret_detection',
          'severity' => 'critical',
          'location' => existing_vulnerability_finding.location.as_json,
          'path' => existing_vulnerability_finding.vulnerability.present.location_link
        }
      end

      let(:violations_count) { 1 }

      let(:violation_details) do
        {
          fail_open_policies: [],
          fail_closed_policies: [security_policy_name],
          warn_mode_policies: [],
          new_scan_finding_violations: [expected_new_finding_json],
          previous_scan_finding_violations: [expected_existing_finding_json],
          license_scanning_violations: [],
          any_merge_request_violations: [],
          errors: [],
          comparison_pipelines: [{ "report_type" => "scan_finding", "source" => [pipeline.id], "target" => [] }]
        }
      end

      it_behaves_like 'recording the audit event'
    end

    context 'when there are any merge request violations' do
      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :any_merge_request, security_policy: security_policy)
      end

      let(:any_merge_request_violation_json) do
        {
          'name' => security_policy_name,
          'commits' => true
        }
      end

      let(:violations_count) { 1 }

      let(:violation_details) do
        {
          fail_open_policies: [],
          fail_closed_policies: [security_policy_name],
          warn_mode_policies: [],
          new_scan_finding_violations: [],
          previous_scan_finding_violations: [],
          license_scanning_violations: [],
          any_merge_request_violations: [any_merge_request_violation_json],
          errors: [],
          comparison_pipelines: []
        }
      end

      before do
        policy = create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: policy_configuration)

        create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
          scan_result_policy_read: policy, name: security_policy_name)

        build_violation_details(policy, violations: { any_merge_request: { commits: true } })
      end

      it_behaves_like 'recording the audit event'
    end

    context 'when there are license scanning violations' do
      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :license_finding, security_policy: security_policy)
      end

      let(:license_scanning_violations_json) do
        {
          "dependencies" => %w[A B],
          "license" => "MIT License",
          "url" => "https://spdx.org/licenses/MIT.html"
        }
      end

      let(:violations_count) { 1 }

      let(:violation_details) do
        {
          fail_open_policies: [],
          fail_closed_policies: [security_policy_name],
          warn_mode_policies: [],
          new_scan_finding_violations: [],
          previous_scan_finding_violations: [],
          license_scanning_violations: [license_scanning_violations_json],
          any_merge_request_violations: [],
          errors: [],
          comparison_pipelines: []
        }
      end

      before do
        policy = create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: policy_configuration)

        create(:report_approver_rule, :license_scanning, merge_request: merge_request,
          scan_result_policy_read: policy, name: security_policy_name)

        build_violation_details(policy,
          violations: { license_scanning: { 'MIT License' => %w[A B] } }
        )
      end

      it_behaves_like 'recording the audit event'
    end

    context "when there are errors" do
      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
      end

      let_it_be(:policy) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: policy_configuration)
      end

      let_it_be(:approver_rule_policy) do
        create(:report_approver_rule, :scan_finding,
          merge_request: merge_request,
          scan_result_policy_read: policy,
          name: security_policy_name
        )
      end

      let_it_be(:errors_json) do
        { "data" => { "missing_scans" => ["sast"] },
          "error" => "SCAN_REMOVED",
          "message" => "There is a mismatch between the scans of the source and target pipelines. " \
            "The following scans are missing: Sast",
          "report_type" => "scan_finding",
          "warning" => false }
      end

      let(:violations_count) { 1 }

      let(:violation_details) do
        {
          fail_open_policies: [],
          fail_closed_policies: [security_policy_name],
          warn_mode_policies: [],
          new_scan_finding_violations: [],
          previous_scan_finding_violations: [],
          license_scanning_violations: [],
          any_merge_request_violations: [],
          errors: [errors_json],
          comparison_pipelines: []
        }
      end

      before do
        build_violation_with_error(policy,
          Security::ScanResultPolicyViolation::ERRORS[:scan_removed], 'missing_scans' => %w[sast])
      end

      it_behaves_like 'recording the audit event'
    end

    context 'when there are running violations' do
      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
      end

      let_it_be(:policy) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: policy_configuration)
      end

      let_it_be(:approver_rule_policy) do
        create(:report_approver_rule, :scan_finding,
          merge_request: merge_request,
          scan_result_policy_read: policy
        )
      end

      let_it_be(:running_violation) do
        build_violation_details(policy, {}, :running)
      end

      it_behaves_like 'not recording the audit event'
    end

    context 'when there are no violations' do
      it_behaves_like 'not recording the audit event'
    end
  end
end
