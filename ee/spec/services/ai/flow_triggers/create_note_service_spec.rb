# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::CreateNoteService, feature_category: :duo_agent_platform do
  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be(:author) { create(:service_account, maintainer_of: project) }
  let_it_be(:resource) { create(:issue, project: project) }
  let_it_be(:existing_note) { create(:note, project: project, noteable: resource) }
  let_it_be(:discussion) { existing_note.discussion }

  let(:params) { { input: 'test input', event: 'mention' } }

  subject(:service) do
    described_class.new(
      project: project,
      resource: resource,
      author: author,
      discussion: discussion
    )
  end

  describe '#execute' do
    let_it_be(:workflow_workload) { create(:duo_workflows_workload, project: project) }
    let_it_be(:workflow) { workflow_workload.workflow }

    let(:mock_response) { ServiceResponse.success(payload: workflow_workload.workload) }

    context 'when block yields successful response' do
      it 'creates initial note, yields with discussion_id, and updates note with success message' do
        expect(Notes::CreateService).to receive(:new).with(
          project,
          author,
          note: '🔄 Processing the request and starting the agent...',
          noteable: resource,
          in_reply_to_discussion_id: discussion.id
        ).and_call_original

        initial_note_count = Note.count

        response = service.execute(params) do |yielded_params|
          expect(yielded_params).to eq(params.merge(discussion_id: discussion.id))
          expect(yielded_params[:discussion_id]).to be_present

          [mock_response, workflow]
        end

        expect(response).to eq(mock_response)
        expect(Note.count).to eq(initial_note_count + 1)

        created_note = Note.last
        expect(created_note.note).to include('✅ Agent has started. You can view the progress')
        expect(created_note.note).to match(/automate.agent.sessions.#{workflow.id}/)
        expect(created_note.note).to include('target="_blank" rel="noopener noreferrer"')
      end
    end

    context 'when block yields error response' do
      let(:error_response) { ServiceResponse.error(message: 'Something went wrong') }

      it 'creates initial note and updates with error message' do
        initial_note_count = Note.count

        response = service.execute(params) { [error_response, workflow] }

        expect(response).to eq(error_response)
        expect(Note.count).to eq(initial_note_count + 1)

        created_note = Note.last
        expect(created_note.note).to include('❌ Could not start the agent due to this error: Something went wrong')
      end
    end

    context 'when no discussion is provided' do
      subject(:service) do
        described_class.new(
          project: project,
          resource: resource,
          author: author,
          discussion: nil
        )
      end

      it 'creates note without in_reply_to_discussion_id' do
        expect(Notes::CreateService).to receive(:new).with(
          project,
          author,
          note: '🔄 Processing the request and starting the agent...',
          noteable: resource,
          in_reply_to_discussion_id: nil
        ).and_call_original

        service.execute(params) { [mock_response, workflow] }
      end
    end

    context 'when resource is a merge request' do
      let_it_be(:merge_request) do
        create(:merge_request,
          source_project: project,
          target_project: project,
          source_branch: 'feature-branch',
          target_branch: 'main'
        )
      end

      let_it_be(:resource) { merge_request }

      it 'creates note on merge request' do
        expect(Notes::CreateService).to receive(:new).with(
          project,
          author,
          note: '🔄 Processing the request and starting the agent...',
          noteable: merge_request,
          in_reply_to_discussion_id: discussion.id
        ).and_call_original

        service.execute(params) { [mock_response, workflow] }
      end
    end
  end
end
