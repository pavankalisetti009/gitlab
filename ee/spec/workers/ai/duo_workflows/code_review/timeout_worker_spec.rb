# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::TimeoutWorker, feature_category: :code_review_workflow do
  subject(:worker) { described_class.new }

  let_it_be(:duo_code_review_bot) { create(:user, :duo_code_review_bot) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  describe '#perform' do
    let(:update_service) { instance_double(MergeRequests::UpdateReviewerStateService) }
    let(:service_result) { ServiceResponse.success }

    before do
      allow(MergeRequests::UpdateReviewerStateService)
        .to receive(:new)
        .with(project: merge_request.project, current_user: duo_code_review_bot)
        .and_return(update_service)

      allow(update_service).to receive(:execute).and_return(service_result)
      allow(Gitlab::AppLogger).to receive(:info)
    end

    context 'when merge request does not exist' do
      it 'returns early when merge request is not found' do
        expect(update_service).not_to receive(:execute)

        worker.perform(non_existing_record_id)
      end
    end

    context 'when review bot does not exist' do
      it 'returns early when review bot is not found' do
        allow(Users::Internal).to receive(:duo_code_review_bot).and_return(nil)

        expect(update_service).not_to receive(:execute)

        worker.perform(merge_request.id)
      end
    end

    context 'when reviewer is already in reviewed state' do
      before do
        merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot, state: 'reviewed')
      end

      it 'returns early without updating state' do
        expect(update_service).not_to receive(:execute)

        worker.perform(merge_request.id)
      end
    end

    context 'when reviewer is not in reviewed state' do
      before do
        merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot, state: 'review_started')
      end

      it 'updates review state to reviewed' do
        worker.perform(merge_request.id)

        expect(update_service).to have_received(:execute).with(merge_request, 'reviewed')
      end

      context 'when update is successful' do
        it 'logs timeout reset message' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            message: "Duo Code Review Flow timed out and was reset",
            event: "duo_code_review_flow_timeout_reset",
            unit_primitive: 'review_merge_request',
            merge_request_id: merge_request.id,
            project_id: project.id
          )

          worker.perform(merge_request.id)
        end
      end

      context 'when update fails' do
        let(:service_result) { ServiceResponse.error(message: 'Update failed') }

        it 'does not log timeout reset message' do
          expect(Gitlab::AppLogger).not_to receive(:info).with(
            hash_including(event: "duo_code_review_flow_timeout_reset")
          )

          worker.perform(merge_request.id)
        end
      end
    end

    context 'when an error occurs' do
      before do
        merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot, state: 'review_started')
        allow(update_service).to receive(:execute).and_raise(StandardError.new('Something went wrong'))
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(StandardError),
          merge_request_id: merge_request.id
        )

        worker.perform(merge_request.id)
      end
    end
  end
end
