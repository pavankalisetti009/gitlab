# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::Refresh::ApprovalService, feature_category: :code_review_workflow do
  include ProjectForksHelper
  include UserHelpers

  let(:group) { create(:group) }
  let(:project) do
    create(:project, :repository, namespace: group, approvals_before_merge: 1, reset_approvals_on_push: true)
  end

  let(:forked_project) { fork_project(project, fork_user, repository: true) }

  let(:fork_user) { create(:user) }

  let(:source_branch) { 'between-create-delete-modify-move' }

  let(:merge_request) do
    create(:merge_request,
      source_project: project,
      source_branch: source_branch,
      target_branch: 'master',
      target_project: project)
  end

  let(:another_merge_request) do
    create(:merge_request,
      source_project: project,
      source_branch: source_branch,
      target_branch: 'test',
      target_project: project)
  end

  let(:forked_merge_request) do
    create(:merge_request,
      source_project: forked_project,
      source_branch: source_branch,
      target_branch: 'master',
      target_project: project)
  end

  let(:oldrev) { TestEnv::BRANCH_SHA[source_branch] }
  let(:newrev) { TestEnv::BRANCH_SHA['after-create-delete-modify-move'] } # Pretend source_branch is now updated
  let(:service) { described_class.new(project: project, current_user: current_user) }
  let(:current_user) { merge_request.author }

  subject(:execute) { service.execute(oldrev, newrev, "refs/heads/#{source_branch}") }

  describe '#execute' do
    describe '#update_approvers_for_target_branch_merge_requests' do
      shared_examples_for 'does not refresh the code owner rules' do
        specify do
          expect(::MergeRequests::SyncCodeOwnerApprovalRules).not_to receive(:new)
          execute
        end
      end

      subject(:execute) { service.execute(oldrev, newrev, "refs/heads/master") }

      let(:enable_code_owner) { true }
      let!(:protected_branch) do
        create(:protected_branch, name: 'master', project: project, code_owner_approval_required: true)
      end

      let(:newrev) { TestEnv::BRANCH_SHA['with-codeowners'] }

      before do
        stub_licensed_features(code_owner_approval_required: true, code_owners: enable_code_owner)
      end

      context 'when the feature flags are enabled' do
        context 'when the branch is protected' do
          context 'when code owners file is updated' do
            let(:irrelevant_merge_request) { another_merge_request }
            let(:relevant_merge_request) { merge_request }

            context 'when not on the merge train' do
              it 'refreshes the code owner rules for all relevant merge requests' do
                fake_refresh_service = instance_double(::MergeRequests::SyncCodeOwnerApprovalRules)

                expect(::MergeRequests::SyncCodeOwnerApprovalRules)
                  .to receive(:new).with(relevant_merge_request).and_return(fake_refresh_service)
                expect(fake_refresh_service).to receive(:execute)

                expect(::MergeRequests::SyncCodeOwnerApprovalRules)
                  .not_to receive(:new).with(irrelevant_merge_request)

                execute
              end
            end

            context 'when on the merge train' do
              let(:merge_request) do
                create(
                  :merge_request,
                  :on_train,
                  source_project: project,
                  source_branch: source_branch,
                  target_branch: 'master',
                  target_project: project
                )
              end

              it_behaves_like 'does not refresh the code owner rules'
            end
          end

          context 'when code owners file is not updated' do
            let(:newrev) { TestEnv::BRANCH_SHA['after-create-delete-modify-move'] }

            it_behaves_like 'does not refresh the code owner rules'
          end

          context 'when the branch is deleted' do
            let(:newrev) { Gitlab::Git::SHA1_BLANK_SHA }

            it_behaves_like 'does not refresh the code owner rules'
          end

          context 'when the branch is created' do
            let(:oldrev) { Gitlab::Git::SHA1_BLANK_SHA }

            it_behaves_like 'does not refresh the code owner rules'
          end
        end

        context 'when the branch is not protected' do
          let(:protected_branch) { nil }

          it_behaves_like 'does not refresh the code owner rules'
        end
      end

      context 'when code_owners is disabled' do
        let(:enable_code_owner) { false }

        it_behaves_like 'does not refresh the code owner rules'
      end
    end

    describe '#sync_any_merge_request_approval_rules' do
      let(:merge_request_1) { merge_request }
      let(:merge_request_2) { another_merge_request }

      let!(:scan_result_policy_read) { create(:scan_result_policy_read, :targeting_commits, project: project) }

      it 'enqueues SyncAnyMergeRequestApprovalRulesWorker for all merge requests with the same source branch' do
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request_1.id)
        )
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request_2.id)
        )

        execute
      end

      context 'when scan_result_policy_read does not target commits' do
        let!(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end

      context 'without scan_result_policy_read' do
        let!(:scan_result_policy_read) { nil }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end
    end

    describe '#sync_unenforceable_approval_rules' do
      shared_examples 'it enqueues the UnenforceablePolicyRulesNotificationWorker' do
        it 'enqueues the expected UnenforceablePolicyRulesNotificationWorker' do
          expect(Security::UnenforceablePolicyRulesNotificationWorker).to(
            receive(:perform_async).with(merge_request.id)
          )

          execute
        end
      end

      shared_examples 'it does not enqueue the UnenforceablePolicyRulesNotificationWorker' do
        it 'does not enqueue the UnenforceablePolicyRulesNotificationWorker' do
          expect(Security::UnenforceablePolicyRulesNotificationWorker).not_to(
            receive(:perform_async).with(merge_request.id)
          )

          execute
        end
      end

      context 'when the merge request has no pipeline' do
        let(:merge_request) do
          create(:merge_request,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'master',
            target_project: project)
        end

        it_behaves_like 'it enqueues the UnenforceablePolicyRulesNotificationWorker'
      end

      context 'when the merge request has a pipeline' do
        let(:merge_request) do
          create(:merge_request,
            :with_head_pipeline,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'master',
            target_project: project)
        end

        it_behaves_like 'it does not enqueue the UnenforceablePolicyRulesNotificationWorker'
      end

      context 'when the merge request is created for a different source branch' do
        let(:merge_request) do
          create(:merge_request,
            source_project: project,
            source_branch: 'feature',
            target_branch: 'master',
            target_project: project
          )
        end

        it_behaves_like 'it does not enqueue the UnenforceablePolicyRulesNotificationWorker'
      end
    end

    describe '#sync_preexisting_states_approval_rules' do
      let(:irrelevant_merge_request) { another_merge_request }
      let(:relevant_merge_request) { merge_request }

      let!(:scan_finding_rule) do
        create(:report_approver_rule, :scan_finding, merge_request: relevant_merge_request)
      end

      it 'enqueues SyncPreexistingStatesApprovalRulesWorker' do
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
          receive(:perform_async).with(relevant_merge_request.id)
        )
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).not_to(
          receive(:perform_async).with(irrelevant_merge_request.id)
        )

        execute
      end

      context 'with license_finding rule' do
        let!(:license_finding_rule) do
          create(:report_approver_rule, :license_scanning, merge_request: relevant_merge_request)
        end

        it 'enqueues SyncPreexistingStatesApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
            receive(:perform_async).with(relevant_merge_request.id)
          )

          execute
        end
      end

      context 'without scan_finding rule' do
        let!(:scan_finding_rule) { nil }

        it 'does not enqueue SyncPreexistingStatesApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end
    end

    describe '#update_approvers_for_source_branch_merge_requests' do
      let(:owner) { create(:user, username: 'default-codeowner') }
      let(:current_user) { merge_request.author }
      let(:service) { described_class.new(project: project, current_user: current_user) }
      let(:enable_code_owner) { true }
      let(:enable_report_approver_rules) { true }
      let_it_be(:file) do
        File.read(Rails.root.join("ee/spec/fixtures/codeowners_example"))
      end

      before do
        stub_licensed_features(code_owners: enable_code_owner)
        stub_licensed_features(report_approver_rules: enable_report_approver_rules)

        group.add_maintainer(fork_user)
        project.add_maintainer(owner)

        project.repository.create_file(owner, 'CODEOWNERS', file, branch_name: 'test', message: 'codeowners')

        merge_request
        another_merge_request
        forked_merge_request
      end

      it 'gets called in a specific order' do
        expect(service).to receive(:update_approvers_for_source_branch_merge_requests).ordered
        expect(service).to receive(:reset_approvals_for_merge_requests).ordered

        execute
      end

      context "when creating approval_rules", :sidekiq_inline do
        shared_examples_for 'creates an approval rule based on current diff' do
          it "creates expected approval rules" do
            expect(another_merge_request.approval_rules.size).to eq(approval_rules_size)
            expect(another_merge_request.approval_rules.first.rule_type).to eq('code_owner')
          end
        end

        before do
          execute
        end

        context 'with a non-sectional codeowners file' do
          it_behaves_like 'creates an approval rule based on current diff' do
            let(:approval_rules_size) { 3 }
          end
        end

        context 'with a sectional codeowners file' do
          let_it_be(:file) do
            File.read(Rails.root.join("ee/spec/fixtures/sectional_codeowners_example"))
          end

          it_behaves_like 'creates an approval rule based on current diff' do
            let(:approval_rules_size) { 9 }
          end
        end
      end

      context 'when code owners disabled' do
        let(:enable_code_owner) { false }

        it 'does nothing' do
          expect(::Gitlab::CodeOwners).not_to receive(:for_merge_request)

          execute
        end
      end

      context 'when code owners enabled' do
        let(:relevant_merge_requests) { [merge_request, another_merge_request] }

        it 'refreshes the code owner rules for all relevant merge requests' do
          fake_refresh_service = instance_double(::MergeRequests::SyncCodeOwnerApprovalRules)

          relevant_merge_requests.each do |merge_request|
            expect(::MergeRequests::SyncCodeOwnerApprovalRules)
              .to receive(:new).with(merge_request).and_return(fake_refresh_service)
            expect(fake_refresh_service).to receive(:execute)
          end

          execute
        end
      end

      context 'when report_approver_rules enabled, with approval_rule enabled' do
        let(:relevant_merge_requests) { [merge_request, another_merge_request] }

        it 'refreshes the report_approver rules for all relevant merge requests' do
          relevant_merge_requests.each do |merge_request|
            expect_next_instance_of(::MergeRequests::SyncReportApproverApprovalRules, merge_request,
              current_user) do |service|
              expect(service).to receive(:execute)
            end
          end

          execute
        end
      end
    end

    describe '#reset_approvals_for_merge_requests' do
      let_it_be(:user) { create(:user) }

      let(:merge_request) do
        create(:merge_request,
          source_project: project,
          source_branch: 'master',
          target_branch: 'feature',
          target_project: project,
          merge_when_pipeline_succeeds: true,
          merge_user: user)
      end

      let(:forked_project) { fork_project(project, user, repository: true) }
      let(:forked_merge_request) do
        create(:merge_request,
          source_project: forked_project,
          source_branch: 'master',
          target_branch: 'feature',
          target_project: project)
      end

      let(:commits) { merge_request.commits }
      let(:oldrev) { commits.last.id }
      let(:newrev) { commits.first.id }
      let(:approver) { create(:user) }

      before do
        group.add_owner(user)

        merge_request.approvals.create!(user_id: user.id)
        forked_merge_request.approvals.create!(user_id: user.id)

        project.add_developer(approver)

        perform_enqueued_jobs
      end

      def approval_todos(merge_request)
        Todo.where(action: Todo::APPROVAL_REQUIRED, target: merge_request)
      end

      context 'when push to origin repo source branch', :sidekiq_inline do
        it 'resets approvals and does not create approval todos for regular and for merge request' do
          service.execute(oldrev, newrev, 'refs/heads/master')
          reload_mrs

          expect(merge_request.approvals).to be_empty
          expect(forked_merge_request.approvals).not_to be_empty
          expect(approval_todos(merge_request).map(&:user)).to be_empty
          expect(approval_todos(forked_merge_request)).to be_empty
        end

        context "in the time it takes to reset approvals" do
          before do
            allow(MergeRequestResetApprovalsWorker).to receive(:perform_in).and_return(nil)
            # Running the approval refresh service would normally run this worker and remove
            # the flag after 10 seconds, but in our test environment "perform_in" happens
            # instantly... so for testing we're just simulating a long run by returning nil

            service.execute(oldrev, newrev, 'refs/heads/master')
          end

          it "prevents merging" do
            expect(merge_request.approval_state.temporarily_unapproved?).to be_truthy
          end

          it "removes the unmergeable flag after the allotted time" do
            merge_request.approval_state.expire_unapproved_key!

            expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
          end
        end

        context "with a merge request on a merge train" do
          before do
            allow_next_instance_of(MergeRequest) do |instance|
              allow(instance).to receive(:merge_train_car).and_return(true)
            end
          end

          it "does not add an umergeable flag" do
            expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
          end
        end
      end

      context 'when push to origin repo target branch' do
        context 'when all MRs to the target branch had diffs' do
          before do
            service.execute(oldrev, newrev, 'refs/heads/feature')
            reload_mrs
          end

          it 'does not reset approvals' do
            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end
      end

      context 'when push to fork repo source branch' do
        let(:service) { described_class.new(project: forked_project, current_user: user) }

        def refresh
          service.execute(oldrev, newrev, 'refs/heads/master')
          reload_mrs
        end

        context 'when open fork merge request' do
          it 'resets approvals and does not create approval todo in fork', :sidekiq_might_not_need_inline do
            refresh

            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end

        context 'when closed fork merge request' do
          before do
            forked_merge_request.close!
          end

          it 'resets approvals', :sidekiq_might_not_need_inline do
            refresh

            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end
      end

      context 'when push to fork repo target branch' do
        describe 'changes to merge requests' do
          before do
            described_class.new(project: forked_project, current_user: user).execute(oldrev, newrev,
              'refs/heads/feature')
            reload_mrs
          end

          it 'does not reset approvals', :sidekiq_might_not_need_inline do
            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end
      end

      context 'when push to origin repo target branch after fork project was removed' do
        before do
          forked_project.destroy!
          service.execute(oldrev, newrev, 'refs/heads/feature')
          reload_mrs
        end

        it 'does not reset approvals' do
          expect(merge_request.approvals).not_to be_empty
          expect(forked_merge_request.approvals).not_to be_empty
          expect(approval_todos(merge_request)).to be_empty
          expect(approval_todos(forked_merge_request)).to be_empty
        end
      end

      context 'when resetting approvals if they are enabled', :sidekiq_inline do
        context 'when approvals_before_merge is disabled' do
          before do
            project.update!(approvals_before_merge: 0)
            service.execute(oldrev, newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'resets approvals and does not create approval todo for approver' do
            expect(merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
          end
        end

        context 'when reset_approvals_on_push is disabled' do
          before do
            project.update!(reset_approvals_on_push: false)
            service.execute(oldrev, newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'does not reset approvals' do
            expect(merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
          end

          context 'when enforced by policy' do
            let(:configuration) { create(:security_orchestration_policy_configuration) }

            let(:scan_result_policy_read) do
              create(
                :scan_result_policy_read,
                :remove_approvals_with_new_commit,
                security_orchestration_policy_configuration: configuration,
                project: project)
            end

            let!(:violation) do
              create(
                :scan_result_policy_violation,
                merge_request: merge_request,
                scan_result_policy_read: scan_result_policy_read)
            end

            let!(:approval_rule) do
              create(
                :report_approver_rule,
                merge_request: merge_request,
                scan_result_policy_read: scan_result_policy_read)
            end

            it 'resets approvals' do
              service.execute(oldrev, newrev, 'refs/heads/master')

              expect(merge_request.approvals).to be_empty
            end
          end
        end

        context 'when the rebase_commit_sha on the MR matches the pushed SHA' do
          before do
            merge_request.update!(rebase_commit_sha: newrev)
            service.execute(oldrev, newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'resets approvals' do
            expect(merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
          end
        end

        context 'when there are approvals', :sidekiq_inline do
          context 'when closed merge request' do
            before do
              merge_request.close!
              service.execute(oldrev, newrev, 'refs/heads/master')
              reload_mrs
            end

            it 'resets the approvals' do
              expect(merge_request.approvals).to be_empty
              expect(approval_todos(merge_request)).to be_empty
            end
          end

          context 'when opened merge request' do
            before do
              service.execute(oldrev, newrev, 'refs/heads/master')
              reload_mrs
            end

            it 'resets the approvals' do
              expect(merge_request.approvals).to be_empty
              expect(approval_todos(merge_request)).to be_empty
            end
          end
        end
      end

      def reload_mrs
        merge_request.reload
        forked_merge_request.reload
      end
    end
  end
end
