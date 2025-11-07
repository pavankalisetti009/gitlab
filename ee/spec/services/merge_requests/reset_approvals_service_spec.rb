# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ResetApprovalsService, feature_category: :code_review_workflow do
  let_it_be(:current_user) { create(:user) }

  let(:service) { described_class.new(project: project, current_user: current_user) }
  let(:group) { create(:group) }
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, namespace: group, approvals_before_merge: 1, reset_approvals_on_push: true) }

  let(:merge_request) do
    create(:merge_request,
      author: current_user,
      source_project: project,
      source_branch: 'master',
      target_branch: 'feature',
      target_project: project,
      merge_when_pipeline_succeeds: true,
      merge_user: user,
      reviewers: [owner])
  end

  let(:commits) { merge_request.commits }
  let(:oldrev) { commits.last.id }
  let(:newrev) { commits.first.id }
  let(:owner) { create(:user, username: 'co1') }
  let(:approver) { create(:user, username: 'co2') }
  let(:security) { create(:user) }
  let(:notification_service) { spy('notification_service') }

  def approval_todos(merge_request)
    Todo.where(action: Todo::APPROVAL_REQUIRED, target: merge_request)
  end

  def execute_service(method_name, *args)
    case method_name
    when 'execute'
      service.execute(*args)
    when 'execute_with_skip_reset_checks'
      service.execute(*args, skip_reset_checks: true)
    end
  end

  describe "#execute" do
    before do
      stub_licensed_features(multiple_approval_rules: true)
      allow(service).to receive(:execute_hooks)
      allow(NotificationService).to receive(:new) { notification_service }
      project.add_developer(approver)
      project.add_developer(owner)
      perform_enqueued_jobs do
        merge_request.update!(approver_ids: [approver.id, owner.id, current_user.id])
      end
    end

    shared_examples_for 'MergeRequests::ApprovalsResetEvent published' do
      it 'publishes MergeRequests::ApprovalsResetEvent' do
        expect { action }
          .to publish_event(MergeRequests::ApprovalsResetEvent)
          .with(expected_data)
      end
    end

    shared_examples_for 'webhook events triggered' do |expected_action, expected_system_action = 'approvals_reset_on_push'|
      it "triggers #{expected_action} webhook with system: true and system_action" do
        expect(service).to receive(:execute_hooks).with(merge_request, expected_action, system: true, system_action: expected_system_action)
        action
      end
    end

    shared_examples_for 'no webhook events triggered' do
      it 'does not trigger webhook events' do
        expect(service).not_to receive(:execute_hooks)
        action
      end
    end

    shared_examples_for 'MergeRequests::ApprovalsResetEvent not published' do
      it 'does not publish MergeRequests::ApprovalsResetEvent' do
        expect { action }
          .not_to publish_event(MergeRequests::ApprovalsResetEvent)
      end
    end

    shared_examples_for "Executing automerge process worker" do
      context 'when auto merge is enabled' do
        it 'calls automerge process worker' do
          expect(AutoMergeProcessWorker).to receive(:perform_async).with(merge_request.id)

          action
        end
      end

      context 'when auto merge is not enabled' do
        let(:merge_request) do
          create(:merge_request,
            author: current_user,
            source_project: project,
            source_branch: 'master',
            target_branch: 'feature',
            target_project: project,
            merge_user: user,
            reviewers: [owner])
        end

        it 'does not call automerge process worker' do
          expect(AutoMergeProcessWorker).not_to receive(:perform_async)

          action
        end
      end
    end

    where(execute_method: %w[execute execute_with_skip_reset_checks])

    with_them do
      let(:patch_id_sha) { nil }

      let!(:approval_1) do
        create(
          :approval,
          merge_request: merge_request,
          user: approver,
          patch_id_sha: patch_id_sha
        )
      end

      let!(:approval_2) do
        create(
          :approval,
          merge_request: merge_request,
          user: owner,
          patch_id_sha: patch_id_sha
        )
      end

      it 'updates reviewers state' do
        expect { execute_service(execute_method, 'refs/heads/master', newrev) }.to change { merge_request.merge_request_reviewers.first.state }.from("unreviewed").to("unapproved")
      end

      it 'resets all approvals and does not create new todos for approvers' do
        execute_service(execute_method, 'refs/heads/master', newrev)
        merge_request.reload

        expect(merge_request.approvals).to be_empty
        expect(approval_todos(merge_request).map(&:user)).to be_empty
      end

      it 'removes the unmergeable flag after the service is run' do
        merge_request.approval_state.temporarily_unapprove!

        execute_service(execute_method, 'refs/heads/master', newrev)
        merge_request.reload

        expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
      end

      it_behaves_like 'Executing automerge process worker' do
        let(:action) do
          execute_service(execute_method, 'refs/heads/master', newrev)
        end
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) do
          execute_service(execute_method, 'refs/heads/master', newrev)
        end
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) do
          execute_service(execute_method, 'refs/heads/master', newrev)
        end
      end

      it_behaves_like 'MergeRequests::ApprovalsResetEvent published' do
        let(:action) do
          execute_service(execute_method, 'refs/heads/master', newrev)
        end

        let(:expected_data) do
          {
            current_user_id: current_user.id,
            merge_request_id: merge_request.id,
            cause: 'new_push',
            approver_ids: merge_request.approvals.pluck(:user_id)
          }
        end
      end

      context 'when merge request is currently approved' do
        # approval_1 and approval_2 already exist from parent context
        # With 1 approval required and 2 approvals, MR is approved
        # When all approvals are deleted due to patch_id_sha mismatch, triggers unapproved

        it_behaves_like 'webhook events triggered', 'unapproved' do
          let(:action) { execute_service(execute_method, 'refs/heads/master', newrev) }
        end
      end

      context 'when merge request is not currently approved' do
        before do
          merge_request.update!(approvals_before_merge: 3) # Require 3 approvals
          # approval_1 and approval_2 already exist (2 approvals), but we need 3, so MR is not approved and stays not approved
        end

        it_behaves_like 'webhook events triggered', 'unapproval' do
          let(:action) { execute_service(execute_method, 'refs/heads/master', newrev) }
        end
      end

      context 'when approvals patch_id_sha matches MergeRequest#current_patch_id_sha' do
        let(:patch_id_sha) { merge_request.current_patch_id_sha }

        it 'does not delete approvals' do
          execute_service(execute_method, 'refs/heads/master', newrev)

          merge_request.reload

          expect(merge_request.approvals).to contain_exactly(approval_1, approval_2)
        end

        it_behaves_like 'MergeRequests::ApprovalsResetEvent not published' do
          let(:action) do
            execute_service(execute_method, 'refs/heads/master', newrev)
          end
        end

        it_behaves_like 'no webhook events triggered' do
          let(:action) { execute_service(execute_method, 'refs/heads/master', newrev) }
        end
      end

      context 'with temporarily_unapproved flag interactions' do
        context 'when MR has sufficient approvals but is temporarily unapproved' do
          before do
            # MR is approved based on DB (has 2 approvals, needs 1)
            # But temporarily_unapproved flag makes approved? return false
            merge_request.approval_state.temporarily_unapprove!
          end

          it 'triggers unapproved webhook when approvals are reset' do
            expect(service).to receive(:execute_hooks).with(
              merge_request, 'unapproved', system: true, system_action: 'approvals_reset_on_push'
            )

            execute_service(execute_method, 'refs/heads/master', newrev)
          end
        end

        context 'when MR has insufficient approvals and is temporarily unapproved' do
          before do
            merge_request.update!(approvals_before_merge: 3) # Need 3, have 2
            merge_request.approval_state.temporarily_unapprove!
          end

          it 'triggers unapproval webhook when approvals are reset' do
            expect(service).to receive(:execute_hooks).with(
              merge_request, 'unapproval', system: true, system_action: 'approvals_reset_on_push'
            )

            execute_service(execute_method, 'refs/heads/master', newrev)
          end
        end

        context 'when temporarily_unapproved flag expires during reset process' do
          before do
            merge_request.approval_state.temporarily_unapprove!
          end

          it 'removes the temporarily_unapproved flag during reset process' do
            expect(merge_request.approval_state.temporarily_unapproved?).to be true

            execute_service(execute_method, 'refs/heads/master', newrev)

            expect(merge_request.approval_state.temporarily_unapproved?).to be false
          end
        end
      end
    end

    context 'with selective code owner removals' do
      let_it_be(:project) do
        create(:project,
          :repository,
          reset_approvals_on_push: false,
          project_setting_attributes: { selective_code_owner_removals: true }
        )
      end

      let_it_be(:codeowner) do
        project.repository.create_file(
          current_user,
          'CODEOWNERS',
          "*.rb @co1\n*.js @co2",
          message: 'Add CODEOWNERS',
          branch_name: 'master'
        )
      end

      let_it_be(:feature_sha1) do
        project.repository.create_file(
          current_user,
          'another.rb',
          '2',
          message: '2',
          branch_name: 'feature'
        )
      end

      let_it_be(:feature_sha2) do
        project.repository.create_file(
          current_user,
          'some.js',
          '3',
          message: '3',
          branch_name: 'feature'
        )
      end

      let_it_be(:feature_sha3) do
        project.repository.create_file(
          current_user,
          'last.rb',
          '4',
          message: '4',
          branch_name: 'feature'
        )
      end

      let_it_be(:feature2_change_unrelated_to_codeowners) do
        project.repository.add_branch(current_user, 'feature2', 'feature')
        project.repository.create_file(
          current_user,
          'file.txt',
          'text',
          message: 'text file',
          branch_name: 'feature2'
        )
      end

      let(:patch_id_sha) { previous_merge_request_diff.patch_id_sha }

      let!(:previous_merge_request_diff) do
        create(:merge_request_diff,
          merge_request: merge_request,
          head_commit_sha: feature_sha2,
          start_commit_sha: merge_request.target_branch_sha,
          base_commit_sha: merge_request.target_branch_sha
        )
      end

      let!(:merge_request) do
        create(:merge_request,
          # Skip creating the diff so we can specify them for the context
          :skip_diff_creation,
          author: current_user,
          source_project: project,
          source_branch: 'feature',
          target_project: project,
          target_branch: 'master',
          reviewers: [owner]
        )
      end

      before do
        perform_enqueued_jobs do
          merge_request.update!(approver_ids: [approver.id, owner.id, current_user.id])
        end
        create(:any_approver_rule, merge_request: merge_request, users: [approver, owner, security])

        merge_request.approval_rules.regular.each do |rule|
          rule.users = [security]
        end

        previous_merge_request_diff
        merge_request.create_merge_request_diff

        # Note: Approval creation moved to specific contexts that need them
        ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute
      end

      it 'updates reviewers state' do
        # Create an approval that will be reset to test reviewer state change
        create(:approval, merge_request: merge_request, user: owner, patch_id_sha: patch_id_sha)

        expect { service.execute('feature', feature_sha3) }.to change { merge_request.merge_request_reviewers.first.state }.from("unreviewed").to("unapproved")
      end

      context 'when the latest push is related to codeowners' do
        let!(:security_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: security,
            patch_id_sha: patch_id_sha
          )
        end

        let!(:js_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: approver,
            patch_id_sha: patch_id_sha
          )
        end

        let!(:rb_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: owner,
            patch_id_sha: patch_id_sha
          )
        end

        it 'resets code owner approvals with changes' do
          service.execute('feature', feature_sha3)
          merge_request.reload

          expect(merge_request.approvals.count).to eq(2)
          expect(merge_request.approvals).to contain_exactly(security_approval, js_approval)
        end

        it_behaves_like 'MergeRequests::ApprovalsResetEvent published' do
          let(:action) do
            service.execute('feature', feature_sha3)
          end

          let(:expected_data) do
            {
              current_user_id: current_user.id,
              merge_request_id: merge_request.id,
              cause: 'new_push',
              approver_ids: [rb_approval.user_id]
            }
          end
        end

        context 'when merge request is currently approved' do
          # rb_approval already exists from parent context to make MR approved

          it_behaves_like 'webhook events triggered', 'unapproval', 'code_owner_approvals_reset_on_push' do
            let(:action) { service.execute('feature', feature_sha3) }
          end
        end

        context 'when merge request is not currently approved' do
          before do
            merge_request.update!(approvals_before_merge: 2) # Need 2 approvals
            # rb_approval creates 1 approval but we need 2, so MR stays not approved
          end

          it_behaves_like 'webhook events triggered', 'unapproval', 'code_owner_approvals_reset_on_push' do
            let(:action) { service.execute('feature', feature_sha3) }
          end
        end

        context 'with temporarily_unapproved flag' do
          before do
            merge_request.approval_state.temporarily_unapprove!
          end

          it 'triggers unapproval webhook with code owner system_action when temporarily unapproved' do
            expect(service).to receive(:execute_hooks).with(
              merge_request, 'unapproval', system: true, system_action: 'code_owner_approvals_reset_on_push'
            )

            service.execute('feature', feature_sha3)
          end
        end
      end

      context 'when the latest push affects multiple codeowners entries' do
        let(:previous_merge_request_diff) do
          create(:merge_request_diff,
            merge_request: merge_request,
            head_commit_sha: feature_sha1,
            start_commit_sha: merge_request.target_branch_sha,
            base_commit_sha: merge_request.target_branch_sha
          )
        end

        let!(:security_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: security,
            patch_id_sha: patch_id_sha
          )
        end

        let!(:js_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: approver,
            patch_id_sha: patch_id_sha
          )
        end

        let!(:rb_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: owner,
            patch_id_sha: patch_id_sha
          )
        end

        it 'resets code owner approvals with changes' do
          service.execute('feature', feature_sha3)
          merge_request.reload

          expect(merge_request.approvals.count).to eq(1)
          expect(merge_request.approvals).to contain_exactly(security_approval)
        end

        it_behaves_like 'MergeRequests::ApprovalsResetEvent published' do
          let(:action) do
            service.execute('feature', feature_sha3)
          end

          let(:expected_data) do
            {
              current_user_id: current_user.id,
              merge_request_id: merge_request.id,
              cause: 'new_push',
              approver_ids: [js_approval.user_id, rb_approval.user_id]
            }
          end
        end

        context 'when merge request is currently approved' do
          before do
            # js_approval and rb_approval already exist from parent context to make MR approved.
            # Need to set required approvals to 2 so when those approvals get reset
            # the MR will be considered to be previously approved and now unapproved.
            merge_request.update!(approvals_before_merge: 2)
          end

          it_behaves_like 'webhook events triggered', 'unapproved', 'code_owner_approvals_reset_on_push' do
            let(:action) { service.execute('feature', feature_sha3) }
          end
        end

        context 'when merge request is not currently approved' do
          before do
            merge_request.update!(approvals_before_merge: 4) # Need 4 approvals
            # js_approval and rb_approval create 2 approvals but we need 4, so MR stays not approved
          end

          it_behaves_like 'webhook events triggered', 'unapproval', 'code_owner_approvals_reset_on_push' do
            let(:action) { service.execute('feature', feature_sha3) }
          end
        end

        context 'with temporarily_unapproved flag interactions' do
          context 'when MR has sufficient approvals but is temporarily unapproved' do
            before do
              # Need to set required approvals to 2 so when those approvals get reset
              # the MR will be considered to be previously approved and now unapproved.
              merge_request.update!(approvals_before_merge: 2)
              merge_request.approval_state.temporarily_unapprove!
            end

            it 'triggers unapproved webhook with code owner system_action' do
              expect(service).to receive(:execute_hooks).with(
                merge_request, 'unapproved', system: true, system_action: 'code_owner_approvals_reset_on_push'
              )

              service.execute('feature', feature_sha3)
            end
          end

          context 'when MR has insufficient approvals and is temporarily unapproved' do
            before do
              merge_request.update!(approvals_before_merge: 4) # Need 4 approvals
              # js_approval and rb_approval create 2 approvals but we need 4, so MR stays not approved
              merge_request.approval_state.temporarily_unapprove!
            end

            it 'triggers unapproval webhook with code owner system_action' do
              expect(service).to receive(:execute_hooks).with(
                merge_request, 'unapproval', system: true, system_action: 'code_owner_approvals_reset_on_push'
              )

              service.execute('feature', feature_sha3)
            end
          end

          context 'when temporarily_unapproved flag expires during code owner reset process' do
            before do
              merge_request.approval_state.temporarily_unapprove!
            end

            it 'removes the temporarily_unapproved flag during reset process' do
              allow(service).to receive(:execute_hooks)

              expect(merge_request.approval_state.temporarily_unapproved?).to be true

              service.execute('feature', feature_sha3)

              expect(merge_request.approval_state.temporarily_unapproved?).to be false
            end
          end
        end
      end

      context 'when the latest push is not related to codeowners' do
        let!(:merge_request) do
          create(:merge_request,
            # Skip creating the diff so we can specify them for the context
            :skip_diff_creation,
            author: current_user,
            source_project: project,
            source_branch: 'feature2',
            target_project: project,
            target_branch: 'master'
          )
        end

        before do
          ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute
        end

        context 'and codeowners related changes were in a previous push' do
          let(:previous_merge_request_diff) do
            create(:merge_request_diff,
              merge_request: merge_request,
              head_commit_sha: feature_sha3,
              start_commit_sha: merge_request.target_branch_sha,
              base_commit_sha: merge_request.target_branch_sha
            )
          end

          let!(:security_approval) do
            create(
              :approval,
              merge_request: merge_request,
              user: security,
              patch_id_sha: patch_id_sha
            )
          end

          let!(:js_approval) do
            create(
              :approval,
              merge_request: merge_request,
              user: approver,
              patch_id_sha: patch_id_sha
            )
          end

          let!(:rb_approval) do
            create(
              :approval,
              merge_request: merge_request,
              user: owner,
              patch_id_sha: patch_id_sha
            )
          end

          it 'does not reset code owner approvals' do
            expect do
              service.execute('feature2', feature2_change_unrelated_to_codeowners)
            end.not_to change {
              merge_request.reload.approvals.count
            }
            expect(merge_request.approvals).to contain_exactly(security_approval, js_approval, rb_approval)
          end

          it_behaves_like 'MergeRequests::ApprovalsResetEvent not published' do
            let(:action) do
              service.execute('feature2', feature2_change_unrelated_to_codeowners)
            end
          end

          it_behaves_like 'no webhook events triggered' do
            let(:action) { service.execute('feature2', feature2_change_unrelated_to_codeowners) }
          end
        end
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) do
          # Create an approval that will be reset to trigger the GraphQL subscription
          create(:approval, merge_request: merge_request, user: owner, patch_id_sha: patch_id_sha)

          service.execute('feature', feature_sha3)
        end
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) do
          # Create an approval that will be reset to trigger the GraphQL subscription
          create(:approval, merge_request: merge_request, user: owner, patch_id_sha: patch_id_sha)

          service.execute('feature', feature_sha3)
        end
      end

      context 'when approvals patch_id_sha matches MergeRequest#current_patch_id_sha' do
        let(:patch_id_sha) { merge_request.current_patch_id_sha }

        let!(:security_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: security,
            patch_id_sha: patch_id_sha
          )
        end

        let!(:js_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: approver,
            patch_id_sha: patch_id_sha
          )
        end

        let!(:rb_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: owner,
            patch_id_sha: patch_id_sha
          )
        end

        it 'does not delete any code owner approvals' do
          service.execute('feature', feature_sha3)
          merge_request.reload

          expect(merge_request.approvals.count).to eq(3)
          expect(merge_request.approvals).to contain_exactly(security_approval, js_approval, rb_approval)
        end

        it_behaves_like 'MergeRequests::ApprovalsResetEvent not published' do
          let(:action) do
            service.execute('feature', feature_sha3)
          end
        end

        it_behaves_like 'no webhook events triggered' do
          let(:action) { service.execute('feature', feature_sha3) }
        end
      end

      context 'when cause is not :new_push' do
        let!(:security_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: security,
            patch_id_sha: patch_id_sha
          )
        end

        let!(:rb_approval) do
          create(
            :approval,
            merge_request: merge_request,
            user: owner,
            patch_id_sha: patch_id_sha
          )
        end

        it 'does not trigger webhook events for non-new_push causes' do
          # Manually call the service method with a different cause
          allow(service).to receive(:trigger_code_owner_webhook_events).and_call_original
          expect(service).not_to receive(:execute_hooks)

          # Use delete_code_owner_approvals directly with a different cause
          service.send(:delete_code_owner_approvals, merge_request, patch_id_sha: patch_id_sha, cause: :something_else)
        end
      end
    end

    describe 'duration logging' do
      before do
        create(:approval, merge_request: merge_request, user: approver)
        create(:approval, merge_request: merge_request, user: owner)

        # Mock logger to avoid noise
        allow(Gitlab::AppJsonLogger).to receive(:info)
      end

      it 'logs operation durations' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            'event' => 'merge_requests_reset_approvals_service',
            'reset_approvals_for_merge_requests_duration_s' => be_a(Float),
            'find_merge_requests_duration_s' => be_a(Float),
            'process_merge_requests_duration_s' => be_a(Float),
            'current_patch_id_sha_total_duration_s' => be_a(Float),
            'delete_all_approvals_total_duration_s' => be_a(Float),
            'reset_approvals_service_total_duration_s' => be_a(Float),
            'reset_approvals_total_duration_s' => be_a(Float)
          )
        ).and_call_original

        service.execute('refs/heads/master', newrev)
      end

      it 'calculates total duration correctly' do
        # Mock monotonic time to return predictable values
        time_sequence = (0..20).map { |i| i * 0.1 }
        allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(*time_sequence)

        expect(Gitlab::AppJsonLogger).to receive(:info) do |log_data|
          expect(log_data['reset_approvals_service_total_duration_s']).to be > 0
          expect(log_data['reset_approvals_service_total_duration_s']).to eq(
            log_data.except('event', 'reset_approvals_service_total_duration_s').values.sum
          )
        end.and_call_original

        service.execute('refs/heads/master', newrev)
      end

      context 'when log_merge_request_reset_approvals_duration feature flag is disabled' do
        before do
          stub_feature_flags(log_merge_request_reset_approvals_duration: false)
        end

        it 'does not measure durations' do
          expect(Gitlab::AppJsonLogger)
            .not_to receive(:info)
            .with(hash_including('event' => 'merge_requests_reset_approvals_service'))

          service.execute('refs/heads/master', newrev)
        end
      end
    end
  end
end
