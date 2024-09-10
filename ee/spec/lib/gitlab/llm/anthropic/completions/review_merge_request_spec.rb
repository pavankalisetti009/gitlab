# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Completions::ReviewMergeRequest, feature_category: :code_review_workflow do
  let(:review_prompt_class) { Gitlab::Llm::Templates::ReviewMergeRequest }
  let(:summary_prompt_class) { Gitlab::Llm::Templates::SummarizeReview }
  let(:tracking_context) { { action: :review_merge_request, request_id: 'uuid' } }
  let(:options) { {} }
  let(:response_modifier) { double }
  let(:create_note_allowed?) { true }

  let(:review_start_note) do
    s_("DuoCodeReview|Hey :wave: I'm starting to review your merge request and I will let you know when I'm finished.")
  end

  let(:review_no_comment_note) do
    s_("DuoCodeReview|I finished my review and found nothing to comment on. Nice work! :tada:")
  end

  let(:review_error_note) do
    s_("DuoCodeReview|I have encountered some issues while I was reviewing. Please try again later.")
  end

  let_it_be(:duo_code_review_bot) { create(:user, :duo_code_review_bot) }
  let_it_be(:project) do
    create(:project, :custom_repo, files: { 'UPDATED.md' => "existing line 1\nexisting line 2\n" })
  end

  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:source_branch) { 'review-merge-request-test' }
  let_it_be(:merge_request) do
    project.repository.create_branch(source_branch, project.default_branch)
    project.repository.update_file(
      user,
      'UPDATED.md',
      "existing line 1\nnew line\n",
      message: 'Update file',
      branch_name: source_branch)

    project.repository.create_file(
      user,
      'NEW.md',
      "new line1\nnew line 2\n",
      message: 'Create file',
      branch_name: source_branch)

    create(
      :merge_request,
      target_project: project,
      source_project: project,
      source_branch: source_branch,
      target_branch: project.default_branch
    )
  end

  let_it_be(:diff_refs) { merge_request.diff_refs }

  let(:review_prompt_message) do
    build(:ai_message, :review_merge_request, user: user, resource: merge_request, request_id: 'uuid')
  end

  subject(:completion) { described_class.new(review_prompt_message, review_prompt_class, options) }

  describe '#execute' do
    let(:review_prompt) { { messages: ['This is a review prompt'] } }
    let(:summary_prompt) { { messages: ['This is a summary prompt'] } }
    let(:payload_parameters) do
      {
        temperature: 0,
        maxOutputTokens: 1024,
        topK: 40,
        topP: 0.95
      }
    end

    before do
      allow_next_instance_of(review_prompt_class) do |template|
        allow(template).to receive(:to_prompt).and_return(review_prompt)
      end

      allow_next_instance_of(summary_prompt_class) do |template|
        allow(template).to receive(:to_prompt).and_return(summary_prompt)
      end

      allow_next_instance_of(Gitlab::Llm::Anthropic::Client, user,
        unit_primitive: 'review_merge_request',
        tracking_context: tracking_context
      ) do |client|
        allow(client)
          .to receive(:messages_complete)
          .with(review_prompt)
          .and_return(review_response)
      end

      allow_next_instance_of(Gitlab::Llm::Anthropic::Client, user,
        unit_primitive: 'summarize_review',
        tracking_context: tracking_context
      ) do |client|
        allow(client)
          .to receive(:messages_complete)
          .with(summary_prompt)
          .and_return(summary_response&.to_json)
      end
    end

    context 'when generated review prompt is nil' do
      let(:review_prompt) { nil }

      it 'does not make a request to AI provider' do
        expect(Gitlab::Llm::Anthropic::Client).not_to receive(:new)

        completion.execute
      end
    end

    context 'when the chat client returns a successful response' do
      let(:review_answer) { 'Helpful review with suggestions' }
      let(:review_response) { { content: [{ text: review_answer }] } }

      let(:summary_answer) { 'Helpful review summary' }
      let(:summary_response) { { content: [{ text: summary_answer }] } }

      it 'creates diff notes on new and updated files',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/478424' do
        completion.execute

        diff_notes = merge_request.notes.diff_notes.authored_by(duo_code_review_bot)
        expect(diff_notes.count).to eq 2

        new_file_note = diff_notes[0]
        expect(new_file_note.note).to eq review_answer
        expect(new_file_note.position.to_h).to eq({
          base_sha: diff_refs.base_sha,
          start_sha: diff_refs.start_sha,
          head_sha: diff_refs.head_sha,
          old_path: 'NEW.md',
          new_path: 'NEW.md',
          position_type: 'text',
          old_line: nil,
          new_line: 2,
          line_range: nil,
          ignore_whitespace_change: false
        })

        updated_file_note = diff_notes[1]
        expect(updated_file_note.note).to eq review_answer
        expect(updated_file_note.position.to_h).to eq({
          base_sha: diff_refs.base_sha,
          start_sha: diff_refs.start_sha,
          head_sha: diff_refs.head_sha,
          old_path: 'UPDATED.md',
          new_path: 'UPDATED.md',
          position_type: 'text',
          old_line: nil,
          new_line: 2,
          line_range: nil,
          ignore_whitespace_change: false
        })
      end

      context 'when review note alredy exist on the same position' do
        it 'does not add more notes to the same position' do
          expect do
            described_class.new(review_prompt_message, review_prompt_class, options).execute
          end.to change { merge_request.notes.diff_notes.count }.by(2)
            .and change { merge_request.notes.non_diff_notes.count }.by(1) # review summary

          expect { completion.execute }
            .to not_change { merge_request.notes.diff_notes.count }
            .and change { merge_request.notes.non_diff_notes.count }.by(1) # review summary

          expect(merge_request.notes.last.note).to eq(review_no_comment_note)
        end
      end

      context 'when user is not allowed to create notes' do
        let(:user) { create(:user) }

        it 'does not publish review' do
          expect(DraftNote).not_to receive(:bulk_insert!)
          expect(DraftNotes::PublishService).not_to receive(:new)

          completion.execute
        end
      end

      context 'when there was no comments' do
        let(:review_response) { {} }

        it 'updates progress note with a success message' do
          completion.execute

          expect(merge_request.notes.count).to eq 1
          expect(merge_request.notes.last.note).to eq(review_no_comment_note)
        end
      end

      context 'when review response is nil' do
        let(:review_response) { nil }

        it 'updates progress note with a success message' do
          completion.execute

          expect(merge_request.notes.count).to eq 1
          expect(merge_request.notes.last.note).to eq(review_no_comment_note)
        end
      end

      context 'when there were some comments' do
        context 'when summary returns a successful response' do
          let(:summary_answer) { 'Helpful review summary' }

          it 'updates progress note with a review summary' do
            expect(Notes::CreateService).to receive(:new).with(
              merge_request.project,
              duo_code_review_bot,
              noteable: merge_request,
              note: review_start_note
            ).and_call_original
            allow(Notes::CreateService).to receive(:new).and_call_original

            completion.execute

            expect(merge_request.notes.non_diff_notes.last.note).to eq s_("Helpful review summary")
          end
        end

        context 'when summary returned an error' do
          let(:summary_response) do
            {
              "error" =>
              {
                "message" => 'Oh, no. Something went wrong!'
              }
            }
          end

          it 'updates progress note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 3
            expect(merge_request.notes.diff_notes.count).to eq 2
            expect(merge_request.notes.non_diff_notes.last.note).to eq(review_error_note)
          end
        end

        context 'when summary returned no result' do
          let(:summary_answer) { '' }

          it 'updates progress note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 3
            expect(merge_request.notes.diff_notes.count).to eq 2
            expect(merge_request.notes.non_diff_notes.last.note).to eq(review_error_note)
          end
        end

        context 'when summary response is nil' do
          let(:summary_response) { nil }

          it 'updates progress note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 3
            expect(merge_request.notes.diff_notes.count).to eq 2
            expect(merge_request.notes.non_diff_notes.last.note).to eq(review_error_note)
          end
        end
      end

      context 'when draft notes limit is reached' do
        before do
          stub_const("#{described_class}::DRAFT_NOTES_COUNT_LIMIT", 1)
        end

        it 'creates diff note on the first file only' do
          completion.execute
          diff_notes = merge_request.notes.diff_notes
          expect(diff_notes.count).to eq 1

          expect(diff_notes[0].position.to_h).to eq({
            base_sha: diff_refs.base_sha,
            start_sha: diff_refs.start_sha,
            head_sha: diff_refs.head_sha,
            old_path: 'NEW.md',
            new_path: 'NEW.md',
            position_type: 'text',
            old_line: nil,
            new_line: 2,
            line_range: nil,
            ignore_whitespace_change: false
          })
        end
      end
    end

    context 'when the AI response is <no_issues_found/>' do
      let(:review_response) { { content: [{ text: ' <no_issues_found/> ' }] } }

      it 'does not call DraftNote#new' do
        expect(DraftNote).not_to receive(:new)

        completion.execute
      end

      it 'does not raise an error' do
        expect { completion.execute }.not_to raise_error
      end
    end

    context 'when the chat client returns an unsuccessful response' do
      let(:review_response) { { error: { message: 'Error' } } }

      it 'does not call DraftNote#new' do
        expect(DraftNote).not_to receive(:new)

        completion.execute
      end
    end

    context 'when the AI response is empty' do
      let(:review_response) { {} }

      it 'does not call DraftNote#new' do
        expect(DraftNote).not_to receive(:new)

        completion.execute
      end

      it 'does not raise an error' do
        expect { completion.execute }.not_to raise_error
      end
    end
  end
end
