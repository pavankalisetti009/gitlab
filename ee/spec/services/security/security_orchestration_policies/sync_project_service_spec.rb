# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::SyncProjectService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be_with_refind(:security_policy) { create(:security_policy, :require_approval) }
  let_it_be_with_refind(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

  let(:policy_changes) { { diff: {}, rules_diff: {} } }

  subject(:service) do
    described_class.new(security_policy: security_policy, project: project, policy_changes: policy_changes)
  end

  shared_examples 'with branch exceptions bypass settings for security policy' do
    before do
      security_policy.update!(content: {
        bypass_settings: { branches: [{ source: { name: 'feature' }, target: { name: 'main' } }] }
      })
    end

    it 'tracks internal event', :clean_gitlab_redis_shared_state do
      expect { service.execute }
        .to trigger_internal_events('check_branch_exceptions_bypass_settings_for_approval_policy')
        .with(project: project)
        .and increment_usage_metrics(
          "redis_hll_counters." \
            "count_distinct_project_id_from_check_branch_exceptions_bypass_settings_for_approval_policy_monthly"
        )
    end
  end

  describe '#execute' do
    describe 'policy sync state tracking' do
      include_context 'with policy sync state'

      before do
        state.append_projects([project.id])
      end

      specify do
        expect { service.execute }.to change { state.pending_projects }
                                .from(contain_exactly(project.id.to_s)).to(be_empty)
      end
    end

    context 'when policy_changes is empty' do
      context 'when policy is disabled' do
        before do
          security_policy.update!(enabled: false)
        end

        it 'does not link the policy and rules' do
          expect { service.execute }.to not_change { Security::PolicyProjectLink.count }
            .and not_change { Security::ApprovalPolicyRuleProjectLink.count }
        end
      end

      context 'when policy is enabled' do
        it 'links policy and rules to project' do
          expect { service.execute }
            .to change { Security::PolicyProjectLink.count }.from(0).to(1)
              .and change { Security::ApprovalPolicyRuleProjectLink.count }.from(0).to(1)
        end

        it 'create project approval_rule' do
          expect { service.execute }.to change { project.approval_rules.count }.by(1)
        end

        include_examples 'creates PEP project schedules' do
          subject(:execute) { service.execute }
        end

        context 'when policy_scope is not applicable' do
          before do
            allow_next_found_instance_of(Security::Policy) do |instance|
              allow(instance).to receive(:scope_applicable?).and_return(false)
            end
          end

          it 'does not link the policy and rules' do
            expect { service.execute }.to not_change { Security::PolicyProjectLink.count }
              .and not_change { Security::ApprovalPolicyRuleProjectLink.count }
          end
        end
      end
    end

    context 'when policy_changes exists' do
      shared_context 'when project approval_rules already exists' do
        let_it_be(:project_approval_rule) do
          create(:approval_project_rule, :scan_finding,
            project: project,
            approval_policy_rule: approval_policy_rule,
            security_orchestration_policy_configuration: security_policy.security_orchestration_policy_configuration
          )
        end

        it 'deletes project approval_rules' do
          expect { service.execute }.to change { project.approval_rules.count }.by(-1)
        end
      end

      describe 'changes of rules' do
        context 'when policy is linked to the project' do
          before do
            create(:security_policy_project_link, project: project, security_policy: security_policy)
            create(:approval_policy_rule_project_link, project: project, approval_policy_rule: approval_policy_rule)
          end

          context 'with deleted policy rules' do
            let(:policy_changes) do
              { rules_diff: { deleted: [{ id: approval_policy_rule.id }] } }
            end

            it 'unlinks policy rules project' do
              expect { service.execute }
                .to change { Security::ApprovalPolicyRuleProjectLink.count }.from(1).to(0)
            end

            include_context 'when project approval_rules already exists'
          end

          context 'with created policy rules' do
            let_it_be(:new_approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

            let(:policy_changes) do
              { diff: { enabled: { from: false, to: true } },
                rules_diff: { created: [{ id: new_approval_policy_rule.id }] } }
            end

            it 'links policy rules project' do
              expect { service.execute }
                .to change { Security::ApprovalPolicyRuleProjectLink.count }.from(1).to(2)
            end

            context 'when policy_scope is not applicable' do
              before do
                allow(service).to receive(:scope_applicable?).and_return(false)
              end

              it 'does not link the policy and rules' do
                expect { service.execute }.to not_change { Security::PolicyProjectLink.count }
                  .and not_change { Security::ApprovalPolicyRuleProjectLink.count }
              end
            end

            include_examples 'with branch exceptions bypass settings for security policy'
          end

          context 'with updated policy rules' do
            let(:updated_rule_content) do
              {
                type: 'scan_finding',
                branches: [],
                scanners: %w[dependency_scanning],
                vulnerabilities_allowed: 0,
                severity_levels: %w[critical],
                vulnerability_states: %w[detected]
              }
            end

            let(:policy_changes) do
              {
                rules_diff: {
                  updated: [{
                    id: approval_policy_rule.id,
                    from: {
                      type: 'scan_finding',
                      branches: [],
                      scanners: %w[container_scanning],
                      vulnerabilities_allowed: 0,
                      severity_levels: %w[critical],
                      vulnerability_states: %w[detected]
                    },
                    to: updated_rule_content
                  }]
                }
              }
            end

            let_it_be(:scan_result_policy_read) do
              create(:scan_result_policy_read,
                project: project,
                orchestration_policy_idx: security_policy.policy_index,
                approval_policy_rule: approval_policy_rule,
                rule_idx: approval_policy_rule.rule_index,
                security_orchestration_policy_configuration: security_policy.security_orchestration_policy_configuration
              )
            end

            let_it_be(:project_approval_rule) do
              create(:approval_project_rule, :scan_finding,
                project: project,
                scan_result_policy_read: scan_result_policy_read,
                approval_policy_rule: approval_policy_rule,
                security_orchestration_policy_configuration: security_policy.security_orchestration_policy_configuration
              )
            end

            before do
              approval_policy_rule.update!(content: updated_rule_content)
            end

            it 'updates project approval_rules' do
              service.execute

              expect(project_approval_rule.reload.scanners).to contain_exactly('dependency_scanning')
            end

            context 'when policy is already disabled' do
              before do
                security_policy.update!(enabled: false)
              end

              it 'does not link the policy and rules' do
                expect { service.execute }.to not_change { Security::PolicyProjectLink.count }
                  .and not_change { Security::ApprovalPolicyRuleProjectLink.count }
              end
            end

            include_examples 'with branch exceptions bypass settings for security policy'
          end
        end
      end

      context 'when policy gets disabled' do
        let(:policy_changes) { { diff: { enabled: { from: true, to: false } }, rules_diff: {} } }

        before do
          security_policy.update!(enabled: false)
        end

        context 'when policy was linked to the project' do
          before do
            create(:security_policy_project_link, project: project, security_policy: security_policy)
            create(:approval_policy_rule_project_link, project: project, approval_policy_rule: approval_policy_rule)
          end

          it 'unlinks the project from the security policy' do
            expect { service.execute }.to change { Security::PolicyProjectLink.count }.from(1).to(0)
          end

          it 'unlinks policy rules project if it is an approval policy' do
            expect { service.execute }.to change { Security::ApprovalPolicyRuleProjectLink.count }.from(1).to(0)
          end

          include_context 'when project approval_rules already exists'
        end

        context 'when policy was not linked to the project' do
          it 'does not unlink the project from the security policy' do
            expect { service.execute }.not_to change { Security::PolicyProjectLink.count }
          end

          it 'does not unlink policy rules project if it is an approval policy' do
            expect { service.execute }.not_to change { Security::ApprovalPolicyRuleProjectLink.count }
          end
        end

        context 'with pipeline execution schedule policy' do
          let_it_be_with_refind(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

          before do
            create(:security_pipeline_execution_project_schedule, project: project, security_policy: security_policy)
          end

          it 'deletes project pipeline execution schedule' do
            expect { service.execute }.to change { Security::PipelineExecutionProjectSchedule.count }.from(1).to(0)
          end
        end
      end

      context 'when policy gets enabled' do
        let(:policy_changes) { { diff: { enabled: { from: false, to: true } }, rules_diff: {} } }

        context 'when policy is scoped' do
          before do
            allow(service).to receive_messages(
              policy_scope_changed_and_unscoped?: false,
              policy_scope_changed_and_scoped?: true
            )
          end

          context 'when policy is not linked to project' do
            it 'links policy and rules to project' do
              expect { service.execute }
                .to change { Security::PolicyProjectLink.count }.from(0).to(1)
            end
          end

          context 'when policy is already linked to project' do
            before do
              create(:security_policy_project_link, project: project, security_policy: security_policy)
              create(:approval_policy_rule_project_link, project: project, approval_policy_rule: approval_policy_rule)
            end

            it 'does not change the project links' do
              expect { service.execute }
                .not_to change { Security::PolicyProjectLink.count }
            end
          end
        end

        context 'when policy is unscoped' do
          before do
            allow(service).to receive_messages(
              policy_scope_changed_and_unscoped?: true,
              policy_scope_changed_and_scoped?: false
            )
          end

          context 'when policy is linked to the project' do
            before do
              create(:security_policy_project_link, project: project, security_policy: security_policy)
              create(:approval_policy_rule_project_link, project: project, approval_policy_rule: approval_policy_rule)
            end

            it 'unlinks the project from the security policy' do
              expect { service.execute }.to change { Security::PolicyProjectLink.count }.from(1).to(0)
            end

            it 'unlinks policy rules project if it is an approval policy' do
              expect { service.execute }.to change { Security::ApprovalPolicyRuleProjectLink.count }.from(1).to(0)
            end
          end

          context 'when it is not linked to the project' do
            it 'does not unlink the project from the security policy' do
              expect { service.execute }.not_to change { Security::PolicyProjectLink.count }
            end

            it 'does not unlink policy rules project if it is an approval policy' do
              expect { service.execute }.not_to change { Security::ApprovalPolicyRuleProjectLink.count }
            end
          end
        end
      end

      context 'with scheduled pipeline execution policy' do
        let_it_be(:snoozed_until) { Time.zone.parse("2025-12-24") }
        let_it_be(:snooze) { { until: snoozed_until.iso8601 } }

        let_it_be(:schedule_to) do
          { type: "daily", start_time: "10:00", time_window: { value: 600, distribution: "random" }, snooze: snooze }
        end

        let_it_be(:schedule_from) { schedule_to.except(:snooze) }

        let_it_be(:diff) { { schedules: { from: [schedule_from], to: [schedule_to] } } }
        let_it_be(:policy_changes) do
          {
            diff: diff,
            rules_diff: {
              created: [],
              updated: [],
              deleted: []
            }
          }
        end

        let_it_be(:security_policy) do
          create(
            :security_policy,
            :pipeline_execution_schedule_policy,
            content: {
              content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
              schedules: [schedule_to]
            })
        end

        let_it_be_with_refind(:project_schedule) do
          create(:security_pipeline_execution_project_schedule, project: project, security_policy: security_policy)
        end

        def persisted_schedule
          Security::PipelineExecutionProjectSchedule.for_project(project).for_policy(security_policy).first!
        end

        context 'with experiment enabled' do
          before do
            allow(security_policy.security_orchestration_policy_configuration)
              .to receive(:experiment_enabled?).and_return(true)
          end

          specify do
            expect { service.execute }.to change { persisted_schedule.snoozed_until }.from(nil).to(snoozed_until)
          end

          context 'when policy_scope is not applicable' do
            before do
              allow(service).to receive(:scope_applicable?).and_return(false)
            end

            specify do
              expect { service.execute }.not_to change { persisted_schedule.snoozed_until }
            end
          end

          context 'with feature disabled' do
            before do
              stub_feature_flags(scheduled_pipeline_execution_policies: false)
            end

            specify do
              expect { service.execute }.to change { Security::PipelineExecutionProjectSchedule.count }.from(1).to(0)
            end
          end
        end

        context 'with experiment disabled' do
          specify do
            expect { service.execute }.to change { Security::PipelineExecutionProjectSchedule.count }.from(1).to(0)
          end
        end
      end
    end

    describe 'scheduling warn mode push settings audit events worker' do
      let(:enforcement_type) { 'warn' }
      let(:policy_scope) { { projects: { including: [{ id: project.id }] } } }
      let(:security_policy) do
        create(:security_policy, type: :approval_policy, scope: policy_scope).tap do |policy|
          policy.update!(content: policy.content.merge('enforcement_type' => enforcement_type))
        end
      end

      shared_examples 'scheduling warn mode push settings audit events worker' do
        specify do
          expect(Security::ScanResultPolicies::CreateProjectWarnModePushSettingsAuditEventsWorker)
            .to receive(:perform_async)
            .with(project.id, security_policy.id)

          service.execute
        end
      end

      shared_examples 'not scheduling warn mode push settings audit events worker' do
        specify do
          expect(Security::ScanResultPolicies::CreateProjectWarnModePushSettingsAuditEventsWorker)
            .not_to receive(:perform_async)

          service.execute
        end
      end

      context 'when policy is an approval policy in warn mode and applicable to the project' do
        it_behaves_like 'scheduling warn mode push settings audit events worker'
      end

      context 'when policy is not in warn mode' do
        let(:enforcement_type) { 'enforce' }

        it_behaves_like 'not scheduling warn mode push settings audit events worker'
      end

      context 'when policy is not applicable to the project' do
        let(:policy_scope) { { projects: { excluding: [{ id: project.id }] } } }

        it_behaves_like 'not scheduling warn mode push settings audit events worker'
      end

      context 'when policy is not an approval policy' do
        let(:security_policy) { create(:security_policy, :scan_execution_policy) }

        it_behaves_like 'not scheduling warn mode push settings audit events worker'
      end

      context 'when the policy is disabled' do
        before do
          security_policy.update!(enabled: false)
        end

        it_behaves_like 'not scheduling warn mode push settings audit events worker'
      end
    end
  end
end
