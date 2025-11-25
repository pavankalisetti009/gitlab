# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService, feature_category: :duo_agent_platform do
  let_it_be(:duo_code_review_bot) { create(:user, :duo_code_review_bot) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  let(:service) { described_class.new(user: user, merge_request: merge_request) }

  describe '#execute' do
    let(:create_and_start_service) do
      instance_double(::Ai::DuoWorkflows::CreateAndStartWorkflowService, execute: ServiceResponse.success)
    end

    let(:progress_note) { instance_double(Note, id: 123, present?: true, destroy: true) }

    before do
      allow_next_instance_of(::SystemNotes::MergeRequestsService) do |system_notes|
        allow(system_notes).to receive(:duo_code_review_started).and_return(progress_note)
      end

      allow(::Ai::DuoWorkflows::CreateAndStartWorkflowService)
        .to receive(:new)
        .with(
          container: merge_request.project,
          current_user: user,
          workflow_definition: ::Ai::DuoWorkflows::WorkflowDefinition['code_review/v1'],
          goal: merge_request.iid,
          source_branch: merge_request.source_branch
        ).and_return(create_and_start_service)

      merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot)
    end

    it 'delegates to Duo Agent Platform workflow', :aggregate_failures do
      service.execute

      expect(create_and_start_service).to have_received(:execute)
    end

    it 'calls UpdateReviewerStateService with review states' do
      expect_next_instance_of(
        MergeRequests::UpdateReviewerStateService,
        project: project,
        current_user: duo_code_review_bot
      ) do |update_service|
        expect(update_service).to receive(:execute).with(merge_request, 'review_started')
      end

      service.execute
    end

    it 'schedules timeout cleanup job for 30 minutes' do
      expect(::Ai::DuoWorkflows::CodeReview::TimeoutWorker)
        .to receive(:perform_in)
        .with(30.minutes, merge_request.id)

      service.execute
    end

    it 'tracks review request event for author' do
      merge_request.update!(author: user)

      expect(service).to receive(:track_internal_event).with(
        'request_review_duo_code_review_on_mr_by_author',
        user: user,
        project: project,
        additional_properties: { property: merge_request.id.to_s }
      )

      service.execute
    end

    it 'tracks review request event for non-author' do
      other_user = create(:user, developer_of: project)
      merge_request.update!(author: other_user)

      expect(service).to receive(:track_internal_event).with(
        'request_review_duo_code_review_on_mr_by_non_author',
        user: user,
        project: project,
        additional_properties: { property: merge_request.id.to_s }
      )

      service.execute
    end

    context 'when progress_note creation returns nil' do
      let(:create_and_start_service) do
        instance_double(
          ::Ai::DuoWorkflows::CreateAndStartWorkflowService,
          execute: ServiceResponse.error(message: 'Failed')
        )
      end

      before do
        allow_next_instance_of(::SystemNotes::MergeRequestsService) do |system_notes|
          allow(system_notes).to receive(:duo_code_review_started).and_return(nil)
        end

        allow(::Ai::DuoWorkflows::CreateAndStartWorkflowService)
          .to receive(:new)
          .and_return(create_and_start_service)
      end

      it 'handles nil progress_note in cleanup without errors' do
        expect { service.execute }.not_to raise_error
      end

      it 'does not call destroy on nil progress_note' do
        result = service.execute

        expect(result.success?).to be false
      end

      it 'skips posting error comment when progress_note is nil' do
        service.execute

        merge_request.reload
        # Verify no error note was created since progress_note was nil
        expect(merge_request.notes.non_diff_notes.where(author: duo_code_review_bot)).to be_empty
      end

      it 'does not create a todo when progress_note is nil' do
        expect_any_instance_of(TodoService) do |todo_service|
          expect(todo_service).not_to receive(:new_review)
        end

        service.execute
      end
    end

    shared_examples 'posts error comment and cleans up' do
      it 'posts an error comment to the merge request' do
        expect_next_instance_of(::Notes::CreateService) do |notes_service|
          expect(notes_service).to receive(:execute).and_call_original
        end

        service.execute

        merge_request.reload
        error_note = merge_request.notes.non_diff_notes.last
        expect(error_note.note).to eq(::Ai::CodeReviewMessages.could_not_start_workflow_error)
        expect(error_note.author).to eq(duo_code_review_bot)
      end

      it 'creates a todo for the error' do
        expect_any_instance_of(TodoService) do |todo_service|
          expect(todo_service).to receive(:new_review).with(merge_request, duo_code_review_bot)
        end

        service.execute
      end

      it 'resets review state' do
        expect_next_instance_of(MergeRequests::UpdateReviewerStateService) do |instance|
          expect(instance).to receive(:execute).with(merge_request, 'review_started')
        end
        expect_next_instance_of(MergeRequests::UpdateReviewerStateService) do |instance|
          expect(instance).to receive(:execute).with(merge_request, 'reviewed')
        end

        service.execute
      end

      it 'destroys progress note' do
        expect(progress_note).to receive(:destroy)

        service.execute
      end

      it 'does not schedule timeout cleanup job' do
        expect(::Ai::DuoWorkflows::CodeReview::TimeoutWorker)
          .not_to receive(:perform_in)

        service.execute
      end

      it 'returns an error result' do
        result = service.execute
        expect(result.success?).to be false
      end
    end

    context 'when workflow fails to start' do
      let(:create_and_start_service) do
        instance_double(
          ::Ai::DuoWorkflows::CreateAndStartWorkflowService,
          execute: ServiceResponse.error(message: 'Workflow start failed')
        )
      end

      it_behaves_like 'posts error comment and cleans up'
    end

    context 'when workflow raises an exception' do
      before do
        allow(create_and_start_service).to receive(:execute).and_raise(StandardError.new('Unexpected error'))
      end

      it_behaves_like 'posts error comment and cleans up'

      it 'tracks the exception with correct unit primitive' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(StandardError),
          unit_primitive: 'duo_agent_platform'
        )

        service.execute
      end
    end
  end
end
