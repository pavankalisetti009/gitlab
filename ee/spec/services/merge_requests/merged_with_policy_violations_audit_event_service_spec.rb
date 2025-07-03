# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::MergedWithPolicyViolationsAuditEventService, feature_category: :security_policy_management do
  let_it_be(:merger) { create :user }
  let_it_be(:approver) { create :user, username: 'approver one' }
  let_it_be(:mr_author) { create :user, username: 'author one' }
  let_it_be(:project) { create :project, :repository }
  let_it_be(:merge_time) { Time.now.utc }
  let_it_be_with_reload(:merge_request) do
    create :merge_request,
      :opened,
      title: 'MR One',
      description: 'This was a triumph',
      author: mr_author,
      source_project: project,
      target_project: project
  end

  let_it_be(:policy_project) { create(:project, :repository) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: policy_project)
  end

  let_it_be(:security_policy_name) { 'Test Policy' }
  let_it_be(:security_policy) do
    create(:security_policy, :approval_policy,
      name: security_policy_name,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let(:service) { described_class.new(merge_request) }

  def build_violation_details(policy, data, status = :failed)
    create(:scan_result_policy_violation, status, project: project, merge_request: merge_request,
      scan_result_policy_read: policy, approval_policy_rule: approval_policy_rule, violation_data: data)
  end

  describe '#execute' do
    let(:execute_service) { service.execute }

    let(:audit_context) do
      {
        name: 'merge_request_merged_with_policy_violations',
        author: merger,
        scope: project,
        target: merge_request,
        message: "Merge request with title 'MR One' was merged with 1 security policy violation(s)",
        additional_details: {
          merge_request_title: merge_request.title,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          merged_at: merge_request.merged_at,
          source_branch: merge_request.source_branch,
          target_branch: merge_request.target_branch,
          project_id: project.id,
          project_name: project.name,
          project_full_path: project.full_path,
          violated_policies: [
            {
              policy_id: security_policy.id,
              policy_name: security_policy_name,
              policy_type: 'approval_policy',
              security_policy_management_project_id: policy_project.id,
              security_orchestration_policy_configuration_id: policy_configuration.id
            }
          ],
          security_policy_approval_rules: policy_approval_rules,
          violation_details: violation_details
        }
      }
    end

    shared_examples 'recording the audit event' do
      it 'records a merge_request_merged_with_policy_violations audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

        execute_service
      end
    end

    shared_examples 'not recording the audit event' do
      it 'does not record a merge_request_merged_with_policy_violations audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(anything)

        execute_service
      end
    end

    context 'when merge request is merged' do
      context 'with scan result policy violations' do
        let_it_be(:approval_policy_rule) do
          create(:approval_policy_rule, :license_finding, security_policy: security_policy)
        end

        let_it_be_with_reload(:approval_rule) do
          create(
            :report_approver_rule,
            :license_scanning,
            merge_request: merge_request.reload,
            approval_policy_rule: approval_policy_rule,
            approvals_required: 1,
            user_ids: [approver.id]
          )
        end

        let_it_be(:approval_merge_request_rules_approved_approver) do
          create(:approval_merge_request_rules_approved_approver,
            approval_merge_request_rule: approval_rule, user: approver)
        end

        let(:policy_approval_rules) do
          [
            {
              name: approval_rule.name,
              report_type: 'license_scanning',
              approved: true,
              approvals_required: 1,
              approved_approvers: ['approver one'],
              invalid_rule: false,
              fail_open: false
            }
          ]
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
          merge_request.update!(state_id: MergeRequest.available_states[:merged])
          merge_request.metrics.update!(merged_at: merge_time, merged_by: merger)
        end

        it_behaves_like 'recording the audit event'

        context 'with invalid rules' do
          before do
            approval_rule.update_columns(approvals_required: 2)
          end

          let(:policy_approval_rules) do
            [
              {
                name: approval_rule.name,
                report_type: 'license_scanning',
                approved: false,
                approvals_required: 2,
                approved_approvers: ['approver one'],
                invalid_rule: true,
                fail_open: false
              }
            ]
          end

          it_behaves_like 'recording the audit event'
        end

        context 'when merged by author is not available' do
          before do
            merge_request.metrics.update!(merged_by: nil)
          end

          it 'audits with a deleted author' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
              a_hash_including(
                author: an_instance_of(Gitlab::Audit::DeletedAuthor)
              )
            )

            execute_service
          end
        end
      end

      context 'without scan result policy violations' do
        before do
          merge_request.update!(state_id: MergeRequest.available_states[:merged])
        end

        it_behaves_like 'not recording the audit event'
      end
    end

    context 'when merge request is not merged' do
      before do
        merge_request.update!(state_id: MergeRequest.available_states[:closed])
      end

      it_behaves_like 'not recording the audit event'
    end
  end
end
