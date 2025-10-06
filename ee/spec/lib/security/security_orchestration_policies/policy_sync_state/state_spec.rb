# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicySyncState::State, :clean_gitlab_redis_shared_state, feature_category: :security_policy_management do
  include Security::PolicyCspHelpers

  let(:redis) { Gitlab::Redis::SharedState.pool.checkout }

  let(:merge_request_id) { 1 }
  let(:project_id) { 1 }
  let(:other_project_id) { 2 }

  let_it_be(:organization) { create(:organization, id: Organizations::Organization::DEFAULT_ORGANIZATION_ID) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace) }

  let(:policy_configuration_id) { policy_configuration.id }

  before do
    stub_csp_group(policy_configuration.namespace)
  end

  subject(:state) { described_class.new(policy_configuration.id) }

  describe '.from_application_context' do
    before do
      allow(Gitlab::ApplicationContext).to receive(:current_context_attribute).and_return(context_value)
    end

    subject(:state) { described_class.from_application_context }

    context 'with context key' do
      let(:context_value) { policy_configuration.id.to_s }

      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace) }

      it { is_expected.to be_a(described_class) }
    end

    context 'without context key' do
      let(:context_value) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe '#start_sync' do
    it 'marks pending' do
      expect { state.start_sync }.to change { state.sync_in_progress?(redis) }.from(false).to(true)
    end

    shared_examples 'when disabled' do
      it 'does not mark pending' do
        expect { state.start_sync }.not_to change { state.sync_in_progress?(redis) }.from(false)
      end
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(security_policy_sync_propagation_tracking: false)
      end

      it_behaves_like 'when disabled'
    end

    context 'without CSP configuration' do
      before do
        stub_csp_group(nil)
      end

      it_behaves_like 'when disabled'
    end
  end

  describe '#finish_sync' do
    before do
      state.start_sync
    end

    it 'removes pending' do
      expect { state.finish_sync }.to change { state.sync_in_progress?(redis) }.from(true).to(false)
    end
  end

  describe '#append_projects' do
    context 'when adding new project IDs' do
      it 'adds project IDs as pending' do
        expect { state.append_projects([project_id, other_project_id]) }.to change {
          state.pending_projects
        }.from(be_empty).to(contain_exactly(project_id.to_s, other_project_id.to_s))
      end

      it 'maintains set membership' do
        expect { 2.times { state.append_projects([project_id]) } }.to change {
          state.pending_projects
        }.from(be_empty).to(contain_exactly(project_id.to_s))
      end

      it 'increments the total counter by the number of projects' do
        state.append_projects([1, 2, 3])
        state.append_projects([4, 5])

        expect(state.total_project_count).to be(5)
      end
    end

    shared_examples 'when disabled' do
      it 'does not add pending IDs' do
        expect { state.append_projects([project_id, other_project_id]) }.not_to change {
          state.pending_projects
        }.from(be_empty)
      end
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(security_policy_sync_propagation_tracking: false)
      end

      it_behaves_like 'when disabled'
    end

    context 'without CSP configuration' do
      before do
        stub_csp_group(nil)
      end

      it_behaves_like 'when disabled'
    end
  end

  describe '#finish_project' do
    before do
      state.append_projects([project_id, other_project_id])
    end

    it 'removes a pending project ID' do
      expect { state.finish_project(project_id) }.to change {
        state.pending_projects
      }.from(contain_exactly(project_id.to_s, other_project_id.to_s)).to(contain_exactly(other_project_id.to_s))
    end

    context 'when project ID is not pending' do
      it 'does not alter pending project IDs' do
        expect { state.finish_project(4) }.not_to change {
          state.pending_projects
        }.from(contain_exactly(project_id.to_s, other_project_id.to_s))
      end
    end

    it 'triggers subscription' do
      expect(state).to receive(:trigger_subscription).exactly(:once).and_call_original

      state.finish_project(other_project_id)
    end

    context 'when project has failed before' do
      before do
        state.fail_project(project_id)
      end

      it 'removes the project from failed set' do
        expect { state.finish_project(1) }.to change {
          state.failed_projects
        }.from(contain_exactly(project_id.to_s)).to(be_empty)
      end
    end

    shared_examples 'when disabled' do
      it 'does not remove a pending project ID' do
        expect { state.finish_project(project_id) }.not_to change {
          state.pending_projects
        }.from(contain_exactly(project_id.to_s, other_project_id.to_s))
      end

      it 'does not trigger subscription' do
        expect(state).not_to receive(:trigger_subscription)

        state.finish_project(other_project_id)
      end
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(security_policy_sync_propagation_tracking: false)

        state.clear_memoization(:feature_disabled)
      end

      it_behaves_like 'when disabled'
    end

    context 'without CSP configuration' do
      before do
        stub_csp_group(nil)

        state.clear_memoization(:feature_disabled)
      end

      it_behaves_like 'when disabled'
    end
  end

  describe '#fail_project' do
    it 'adds a project ID as failed' do
      expect { state.fail_project(project_id) }.to change {
        state.failed_projects
      }.from(be_empty).to(contain_exactly(project_id.to_s))
    end

    it 'removes a project ID as pending' do
      state.append_projects([project_id])

      expect { state.fail_project(project_id) }.to change {
        state.pending_projects
      }.from(contain_exactly(project_id.to_s)).to(be_empty)
    end

    it 'maintains set membership' do
      expect { 2.times { state.fail_project(project_id) } }.to change {
        state.failed_projects
      }.from(be_empty).to(contain_exactly(project_id.to_s))
    end

    it 'triggers subscription' do
      expect(state).to receive(:trigger_subscription).exactly(:once).and_call_original

      state.finish_project(project_id)
    end

    shared_examples 'when disabled' do
      it 'does not add a project ID as failed' do
        expect { state.fail_project(project_id) }.not_to change {
          state.failed_projects
        }.from(be_empty)
      end

      it 'does not trigger subscription' do
        expect(state).not_to receive(:trigger_subscription)

        state.finish_project(project_id)
      end
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(security_policy_sync_propagation_tracking: false)
      end

      it_behaves_like 'when disabled'
    end

    context 'without CSP configuration' do
      before do
        stub_csp_group(nil)
      end

      it_behaves_like 'when disabled'
    end
  end

  describe '#start_merge_request' do
    it 'adds a merge request ID as pending' do
      expect { state.start_merge_request(merge_request_id) }.to change {
        state.pending_merge_requests
      }.from(be_empty).to(match_array("1"))
    end

    it 'maintains set membership' do
      expect { 2.times { state.start_merge_request(merge_request_id) } }.to change {
        state.pending_merge_requests
      }.from(be_empty).to(match_array("1"))
    end

    it 'increases total merge request count' do
      expect { state.start_merge_request(merge_request_id) }.to change {
        state.total_merge_request_count
      }.from(nil).to(1)
    end

    it 'initializes merge request worker count' do
      expect { state.start_merge_request(merge_request_id) }.to change {
        state.total_merge_request_workers_count(merge_request_id)
      }.from(nil).to(0)
    end

    shared_examples 'when disabled' do
      it 'does not add a merge request ID as pending' do
        expect { state.start_merge_request(merge_request_id) }.not_to change {
          state.pending_merge_requests
        }.from(be_empty)
      end

      it 'does not increase total merge request count' do
        expect { state.start_merge_request(merge_request_id) }.not_to change {
          state.total_merge_request_count
        }.from(nil)
      end

      it 'does not initialize merge request worker count' do
        expect { state.start_merge_request(merge_request_id) }.not_to change {
          state.total_merge_request_workers_count(merge_request_id)
        }.from(nil)
      end
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(security_policy_sync_propagation_tracking: false)
      end

      it_behaves_like 'when disabled'
    end

    context 'without CSP configuration' do
      before do
        stub_csp_group(nil)
      end

      it_behaves_like 'when disabled'
    end
  end

  describe '#start_merge_request_worker' do
    it 'increases merge request worker count', :aggregate_failures do
      expect { state.start_merge_request_worker(merge_request_id) }.to change {
        state.total_merge_request_workers_count(merge_request_id)
      }.from(nil).to(1)

      expect { state.start_merge_request_worker(merge_request_id) }.to change {
        state.total_merge_request_workers_count(merge_request_id)
      }.from(1).to(2)
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(security_policy_sync_propagation_tracking: false)
      end

      it 'does not increase merge request worker count', :aggregate_failures do
        expect { state.start_merge_request_worker(merge_request_id) }.not_to change {
          state.total_merge_request_workers_count(merge_request_id)
        }.from(nil)

        expect { state.start_merge_request_worker(merge_request_id) }.not_to change {
          state.total_merge_request_workers_count(merge_request_id)
        }.from(nil)
      end
    end

    context 'without CSP configuration' do
      before do
        stub_csp_group(nil)
      end

      it 'does not increase merge request worker count', :aggregate_failures do
        expect { state.start_merge_request_worker(merge_request_id) }.not_to change {
          state.total_merge_request_workers_count(merge_request_id)
        }.from(nil)

        expect { state.start_merge_request_worker(merge_request_id) }.not_to change {
          state.total_merge_request_workers_count(merge_request_id)
        }.from(nil)
      end
    end
  end

  describe '#finish_merge_request_worker' do
    before do
      state.start_merge_request(merge_request_id)
    end

    context 'with last worker' do
      before do
        state.start_merge_request_worker(merge_request_id)
      end

      it 'decrements merge request worker count' do
        expect { state.finish_merge_request_worker(merge_request_id) }.to change {
          state.total_merge_request_workers_count(merge_request_id)
        }.from(1).to(0)
      end

      it 'removes merge request from pending set' do
        expect { state.finish_merge_request_worker(merge_request_id) }.to change {
          state.pending_merge_requests
        }.from(contain_exactly(merge_request_id.to_s)).to(be_empty)
      end

      it 'triggers subscription' do
        expect(state).to receive(:trigger_subscription).exactly(:once).and_call_original

        state.finish_merge_request_worker(merge_request_id)
      end

      shared_examples 'when disabled' do
        it 'does not decrement merge request worker count' do
          expect { state.finish_merge_request_worker(merge_request_id) }.not_to change {
            state.total_merge_request_workers_count(merge_request_id)
          }.from(1)
        end

        it 'does not remove merge request from pending set' do
          expect { state.finish_merge_request_worker(merge_request_id) }.not_to change {
            state.pending_merge_requests
          }.from(contain_exactly(merge_request_id.to_s))
        end

        it 'does not trigger subscription' do
          expect(state).not_to receive(:trigger_subscription)

          state.finish_merge_request_worker(merge_request_id)
        end
      end

      context 'with feature disabled' do
        before do
          stub_feature_flags(security_policy_sync_propagation_tracking: false)

          state.clear_memoization(:feature_disabled)
        end

        it_behaves_like 'when disabled'
      end

      context 'without CSP configuration' do
        before do
          stub_csp_group(nil)

          state.clear_memoization(:feature_disabled)
        end

        it_behaves_like 'when disabled'
      end
    end

    context 'with remaining workers' do
      before do
        2.times { state.start_merge_request_worker(merge_request_id) }
      end

      it 'decrements merge request worker count' do
        expect { state.finish_merge_request_worker(merge_request_id) }.to change {
          state.total_merge_request_workers_count(merge_request_id)
        }.from(2).to(1)
      end

      it 'does not remove merge request from pending set' do
        expect { state.finish_merge_request_worker(merge_request_id) }.not_to change {
          state.pending_merge_requests
        }.from(contain_exactly(merge_request_id.to_s))
      end

      it 'does not trigger subscription' do
        expect(state).not_to receive(:trigger_subscription)

        state.finish_merge_request_worker(merge_request_id)
      end

      shared_examples 'when disabled' do
        it 'does not decrement merge request worker count' do
          expect { state.finish_merge_request_worker(merge_request_id) }.not_to change {
            state.total_merge_request_workers_count(merge_request_id)
          }.from(2)
        end

        it 'does not trigger subscription' do
          expect(state).not_to receive(:trigger_subscription)

          state.finish_merge_request_worker(merge_request_id)
        end
      end

      context 'with feature disabled' do
        before do
          stub_feature_flags(security_policy_sync_propagation_tracking: false)

          state.clear_memoization(:feature_disabled)
        end

        it_behaves_like 'when disabled'
      end

      context 'without CSP configuration' do
        before do
          stub_csp_group(nil)

          state.clear_memoization(:feature_disabled)
        end

        it_behaves_like 'when disabled'
      end
    end
  end

  describe '#sync_in_progress?' do
    subject(:sync_in_progress?) { state.sync_in_progress?(redis) }

    it { is_expected.to be(false) }

    context 'with project and merge request' do
      before do
        state.append_projects([project_id])
        state.start_merge_request(merge_request_id)
        state.start_merge_request_worker(merge_request_id)
      end

      it { is_expected.to be(true) }

      context 'with feature disabled' do
        before do
          stub_feature_flags(security_policy_sync_propagation_tracking: false)

          state.clear_memoization(:feature_disabled)
        end

        it { is_expected.to be(false) }
      end

      context 'without CSP configuration' do
        before do
          stub_csp_group(nil)

          state.clear_memoization(:feature_disabled)
        end

        it { is_expected.to be(false) }
      end

      context 'with all projects processed' do
        before do
          state.finish_project(project_id)
        end

        it { is_expected.to be(true) }
      end

      context 'with all merge request processed' do
        before do
          state.finish_merge_request_worker(merge_request_id)
        end

        it { is_expected.to be(true) }
      end

      context 'with all projects and merge requests processed' do
        before do
          state.finish_project(project_id)
          state.finish_merge_request_worker(merge_request_id)
        end

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#clear' do
    subject(:clear) { state.clear }

    before do
      state.append_projects([project_id])
      state.start_merge_request(merge_request_id)
    end

    it 'resets pending project IDs' do
      expect { clear }.to change { state.pending_projects }.from(contain_exactly(project_id.to_s)).to(be_empty)
    end

    it 'resets pending merge request IDs' do
      expect { clear }.to change {
        state.pending_merge_requests
      }.from(contain_exactly(merge_request_id.to_s)).to(be_empty)
    end

    shared_examples 'when disabled' do
      it 'does not reset pending project IDs' do
        expect { clear }.not_to change { state.pending_projects }.from(contain_exactly(project_id.to_s))
      end

      it 'does not reset pending merge request IDs' do
        expect { clear }.not_to change {
          state.pending_merge_requests
        }.from(contain_exactly(merge_request_id.to_s))
      end
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(security_policy_sync_propagation_tracking: false)

        state.clear_memoization(:feature_disabled)
      end

      it_behaves_like 'when disabled'
    end

    context 'without CSP configuration' do
      before do
        stub_csp_group(nil)

        state.clear_memoization(:feature_disabled)
      end

      it_behaves_like 'when disabled'
    end
  end

  describe '#trigger_subscription' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace) }

    subject(:state) { described_class.new(policy_configuration.id) }

    before do
      10.times do |i|
        state.append_projects([i])
        state.start_merge_request(i)
        state.start_merge_request_worker(i)
      end
    end

    it 'publishes with correct values at each step' do
      expect(GraphqlTriggers).to receive(:security_policies_sync_updated).with(
        policy_configuration,
        10,  # project progress: (10 total - 9 pending) / 10 * 100 = 10%
        10,  # projects total
        [],  # no failed projects yet
        0,   # merge request progress: (10 total - 10 pending) / 10 * 100 = 0%
        10,  # merge requests total,
        true # in progress
      ).ordered
      state.finish_project(1)

      expect(GraphqlTriggers).to receive(:security_policies_sync_updated).with(
        policy_configuration,
        10,  # project progress: still 10%
        10,  # projects total
        [],  # no failed projects yet
        10,  # merge request progress: (10 total - 9 pending) / 10 * 100 = 10%
        10,  # merge requests total,
        true # in progress
      ).ordered
      state.finish_merge_request_worker(1)

      expect(GraphqlTriggers).to receive(:security_policies_sync_updated).with(
        policy_configuration,
        20,    # project progress: (10 total - 8 pending) / 10 * 100 = 20%
        10,    # projects total
        ["2"], # failed project 2
        10,    # merge request progress: still 10%
        10,    # merge requests total,
        true   # in progress
      ).ordered
      state.fail_project(2)
    end

    it 'shows increasing progress as items complete' do
      5.times do |i|
        allow(GraphqlTriggers).to receive(:security_policies_sync_updated)
        state.finish_project(i)
      end

      expect(GraphqlTriggers).to have_received(:security_policies_sync_updated).with(
        policy_configuration,
        50,  # project progress: (10 - 5) / 10 * 100 = 50%
        10,  # projects total
        [],  # no failed projects
        0,   # merge request progress: still 0%
        10,  # merge requests total,
        true # in progress
      )
    end

    context 'when sync is not in progress' do
      before do
        state.clear
      end

      it 'does not trigger subscription' do
        expect(state).not_to receive(:trigger_subscription)

        state.append_projects([1])
      end
    end

    context 'when feature is disabled' do
      before do
        stub_feature_flags(security_policy_sync_propagation_tracking: false)
        state.clear_memoization(:feature_disabled)
      end

      it 'does not trigger subscription' do
        expect(state).not_to receive(:trigger_subscription)

        state.append_projects([1])
      end
    end

    context 'when only projects are pending' do
      before do
        state.clear
        state.append_projects([1, 2, 3])
      end

      it 'triggers subscription when finishing a project' do
        expect(state).to receive(:trigger_subscription).exactly(:once).and_call_original

        state.finish_project(1)
      end
    end

    context 'when only merge requests are pending' do
      before do
        state.clear
        state.start_merge_request(1)
        state.start_merge_request_worker(1)
      end

      it 'triggers subscription when finishing a merge request worker' do
        expect(state).to receive(:trigger_subscription).exactly(:once).and_call_original

        state.finish_merge_request_worker(1)
      end
    end
  end
end
