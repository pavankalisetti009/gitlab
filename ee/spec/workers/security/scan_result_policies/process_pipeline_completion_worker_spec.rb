# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ProcessPipelineCompletionWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:pipeline_finished_event) do
    Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline.id, status: 'success' })
  end

  let(:feature_licensed) { true }
  let(:can_store_security_reports) { true }
  let(:event) { pipeline_finished_event }

  subject(:perform) { consume_event(subscriber: described_class, event: pipeline_finished_event) }

  shared_examples 'schedules SyncFindingsToApprovalRulesWorker' do
    it 'schedules SyncFindingsToApprovalRulesWorker' do
      expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker)
        .to receive(:perform_async).with(pipeline.id)

      perform
    end
  end

  shared_examples 'does not schedule SyncFindingsToApprovalRulesWorker' do
    it 'does not schedule SyncFindingsToApprovalRulesWorker' do
      expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker)
        .not_to receive(:perform_async)

      perform
    end
  end

  before do
    stub_licensed_features(security_orchestration_policies: feature_licensed)
    allow_next_found_instance_of(Project) do |record|
      allow(record).to receive(:can_store_security_reports?).and_return(can_store_security_reports)
    end
  end

  describe 'subscriptions' do
    it_behaves_like 'subscribes to event' do
      let(:event) { pipeline_finished_event }

      it 'receives the event' do
        expect(described_class).to receive(:perform_async).with('Ci::PipelineFinishedEvent',
          pipeline_finished_event.data.deep_stringify_keys)
        ::Gitlab::EventStore.publish(event)
      end
    end
  end

  describe '#handle_event' do
    it_behaves_like 'an idempotent worker'

    context 'when pipeline exists' do
      context 'when security orchestration policies feature is licensed' do
        context 'when project can store security reports' do
          it_behaves_like 'schedules SyncFindingsToApprovalRulesWorker'
        end

        context 'when project cannot store security reports' do
          let(:can_store_security_reports) { false }

          it_behaves_like 'does not schedule SyncFindingsToApprovalRulesWorker'
        end
      end

      context 'when security orchestration policies feature is not licensed' do
        let(:feature_licensed) { false }

        it_behaves_like 'does not schedule SyncFindingsToApprovalRulesWorker'
      end
    end

    context 'when pipeline does not exist' do
      let(:pipeline_finished_event) do
        Ci::PipelineFinishedEvent.new(data: { pipeline_id: non_existing_record_id, status: 'success' })
      end

      it_behaves_like 'does not schedule SyncFindingsToApprovalRulesWorker'
    end
  end
end
