# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker, feature_category: :security_policy_management do
  let_it_be(:merge_request) { create(:ee_merge_request) }

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(merge_request_id) }

    let(:merge_request_id) { merge_request.id }

    it 'calls SyncAnyMergeRequestRulesService' do
      expect_next_instance_of(
        Security::ScanResultPolicies::SyncAnyMergeRequestRulesService,
        merge_request
      ) do |instance|
        expect(instance).to receive(:execute)
      end

      run_worker
    end

    describe 'policy sync state tracking' do
      include_context 'with policy sync state'

      before do
        state.start_merge_request(merge_request_id)
      end

      specify do
        expect { run_worker }.to change { state.pending_merge_requests }
                                   .from(contain_exactly(merge_request_id.to_s)).to(be_empty)
      end
    end

    context 'when merge_request does not exist' do
      let(:merge_request_id) { non_existing_record_id }

      it 'does not call SyncAnyMergeRequestRulesService' do
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestRulesService).not_to receive(:new)

        run_worker
      end
    end
  end
end
