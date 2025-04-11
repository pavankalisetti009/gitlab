# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Completions::ReviewMergeRequest, feature_category: :code_review_workflow do
  let(:review_prompt_class) { Gitlab::Llm::Templates::ReviewMergeRequest }
  let(:summary_prompt_class) { Gitlab::Llm::Templates::SummarizeReview }
  let(:tracking_context) { { action: :review_merge_request, request_id: 'uuid' } }
  let(:options) { { progress_note_id: progress_note.id } }
  let(:create_note_allowed?) { true }

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
  let_it_be(:progress_note) do
    create(
      :note,
      note: 'progress note',
      project: project,
      noteable: merge_request,
      author: Users::Internal.duo_code_review_bot
    )
  end

  let(:review_prompt_message) do
    build(:ai_message, :review_merge_request, user: user, resource: merge_request, request_id: 'uuid')
  end

  subject(:completion) { described_class.new(review_prompt_message, review_prompt_class, options) }

  describe '#execute' do
    let(:first_review_prompt) { { messages: ['This is the first review prompt'] } }
    let(:second_review_prompt) { { messages: ['This is the second review prompt'] } }
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
      allow_next_instance_of(
        review_prompt_class,
        new_path: 'UPDATED.md',
        raw_diff: anything,
        hunk: anything,
        user: user,
        mr_title: merge_request.title,
        mr_description: merge_request.description
      ) do |first_template|
        allow(first_template).to receive(:to_prompt).and_return(first_review_prompt)
      end

      allow_next_instance_of(
        review_prompt_class,
        new_path: 'NEW.md',
        raw_diff: anything,
        hunk: anything,
        user: user,
        mr_title: merge_request.title,
        mr_description: merge_request.description
      ) do |second_template|
        allow(second_template).to receive(:to_prompt).and_return(second_review_prompt)
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
          .with(first_review_prompt)
          .and_return(first_review_response)
        allow(client)
          .to receive(:messages_complete)
          .with(second_review_prompt)
          .and_return(second_review_response)
        allow(client)
          .to receive(:messages_complete)
          .with(summary_prompt)
          .and_return(summary_response&.to_json)
      end
    end

    context 'when generated review prompt is nil' do
      let(:first_review_prompt) { nil }
      let(:second_review_prompt) { nil }

      it 'does not make a request to AI provider' do
        expect(Gitlab::Llm::Anthropic::Client).not_to receive(:new)

        completion.execute
      end
    end

    context 'when merge request has no reviewable files' do
      before do
        allow(merge_request).to receive(:ai_reviewable_diff_files).and_return([])
      end

      it 'creates explanation note' do
        expect(Notes::UpdateService).to receive(:new).with(
          merge_request.project,
          duo_code_review_bot,
          note: described_class.nothing_to_review_msg
        ).and_call_original

        completion.execute

        expect(merge_request.notes.non_diff_notes.last.note).to eq described_class.nothing_to_review_msg
      end
    end

    context 'when the chat client returns a successful response' do
      let(:first_review_response) { { content: [{ text: first_review_answer }] } }
      let(:first_review_answer) do
        <<~RESPONSE
          <review>
          <comment priority="3" old_line="" new_line="2">
          First comment with suggestions
          With additional line
          <from>
              first offending line
                second offending line
          </from>
          <to>
              first improved line
                second improved line
          </to>
          Some more comments
          </comment>
          </review>
        RESPONSE
      end

      let(:second_review_response) { { content: [{ text: second_review_answer }] } }
      let(:second_review_answer) do
        <<~RESPONSE
          <review>
          <comment priority="3" old_line="" new_line="1">Second comment with suggestions</comment>
          <comment priority="3" old_line="" new_line="2">Third comment with suggestions</comment>
          <comment priority="2" old_line="" new_line="2">Fourth comment with suggestions</comment>
          </review>
        RESPONSE
      end

      let(:summary_answer) { 'Helpful review summary' }
      let(:summary_response) { { content: [{ text: summary_answer }] } }

      it 'filters by priority and creates diff notes on new and updated files' do
        completion.execute

        diff_notes = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).reorder(:id)
        expect(diff_notes.count).to eq 3

        first_note = diff_notes[0]
        expect(first_note.note).to eq 'Second comment with suggestions'
        expect(first_note.position.to_h).to eq({
          base_sha: diff_refs.base_sha,
          start_sha: diff_refs.start_sha,
          head_sha: diff_refs.head_sha,
          old_path: 'NEW.md',
          new_path: 'NEW.md',
          position_type: 'text',
          old_line: nil,
          new_line: 1,
          line_range: nil,
          ignore_whitespace_change: false
        })

        second_note = diff_notes[1]
        expect(second_note.note).to eq 'Third comment with suggestions'
        expect(second_note.position.to_h).to eq({
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

        third_note = diff_notes[2]
        expect(third_note.note).to eq <<~NOTE_CONTENT
          First comment with suggestions
          With additional line
          ```suggestion:-0+1
              first improved line
                second improved line
          ```
          Some more comments
        NOTE_CONTENT

        expect(third_note.position.to_h).to eq({
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

      it 'performs review and update progress note' do
        expect do
          completion.execute
        end.to change { merge_request.notes.diff_notes.count }.by(3)
          .and not_change { merge_request.notes.non_diff_notes.count } # review summary just gets updated
        expect(progress_note.reload.note).to eq(summary_answer)
      end

      context 'when review note alredy exist on the same position' do
        let(:progress_note2) do
          create(
            :note,
            note: 'progress note 2',
            project: project,
            noteable: merge_request,
            author: Users::Internal.duo_code_review_bot
          )
        end

        before do
          described_class.new(review_prompt_message, review_prompt_class, progress_note_id: progress_note2.id).execute
        end

        it 'does not add more notes to the same position' do
          expect { completion.execute }
            .to not_change { merge_request.notes.diff_notes.count }
            .and not_change { merge_request.notes.non_diff_notes.count } # review summary just gets updated

          expect(progress_note.reload.note).to eq(described_class.no_comment_msg)
        end
      end

      context 'when resource is empty' do
        let(:review_prompt_message) do
          build(:ai_message, :review_merge_request, user: user, resource: nil, request_id: 'uuid')
        end

        it 'updates progress note and return' do
          expect do
            described_class.new(review_prompt_message, review_prompt_class, options).execute
          end.to not_change { merge_request.notes.diff_notes.count }
            .and not_change { merge_request.notes.non_diff_notes.count }

          expect(progress_note.reload.note).to eq(described_class.resource_not_found_msg)
        end
      end

      context 'when progress note is not provided' do
        let(:options) { {} }

        it 'creates progress note and finish review as expected' do
          expect do
            completion.execute
          end.to change { merge_request.notes.diff_notes.count }.by(3)
            .and change { merge_request.notes.non_diff_notes.count }.by(1) # review summary gets created

          expect(merge_request.notes.non_diff_notes.last.note).to eq(summary_answer)
        end

        context 'when resource is empty' do
          let(:review_prompt_message) do
            build(:ai_message, :review_merge_request, user: user, resource: nil, request_id: 'uuid')
          end

          it 'does not execute review and raise exception' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              StandardError.new("Unable to perform Duo Code Review: progress_note and resource not found")
            )

            expect do
              described_class.new(review_prompt_message, review_prompt_class, options).execute
            end.to not_change { merge_request.notes.diff_notes.count }
              .and not_change { merge_request.notes.non_diff_notes.count }
          end
        end
      end

      context 'when the chat client response includes invalid comments' do
        let(:first_review_response) { { content: [{ text: first_review_answer }] } }
        let(:first_review_answer) do
          <<~RESPONSE
            <review>
            <comment>First comment with suggestions</comment>
            <comment priority="3" old_line="" new_line="2">Second comment with suggestions</comment>
            </review>
          RESPONSE
        end

        let(:second_review_response) { { content: [{ text: second_review_answer }] } }
        let(:second_review_answer) do
          <<~RESPONSE
            <review>
            <comment priority="" old_line="" new_line="1">Third comment with no priority</comment>
            <comment priority="3" old_line="" new_line="">Fourth comment with missing lines</comment>
            <comment priority="3" old_line="" new_line="10">Fifth comment with invalid line</comment>
            </review>
          RESPONSE
        end

        it 'creates a valid comment only' do
          completion.execute

          diff_note = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).sole

          expect(diff_note.note).to eq 'Second comment with suggestions'
          expect(diff_note.position.new_line).to eq(2)
        end
      end

      context 'when the chat client decides to return contents outside of <review> tag' do
        let(:first_review_response) { { content: [{ text: first_review_answer }] } }
        let(:first_review_answer) do
          <<~RESPONSE
            Let me explain how awesome this review is.

            <review>
            <comment priority="3" old_line="" new_line="2">First comment with suggestions</comment>
            </review>
          RESPONSE
        end

        let(:second_review_response) { { content: [{ text: second_review_answer }] } }
        let(:second_review_answer) do
          <<~RESPONSE
            <review>
            <comment priority="3" old_line="" new_line="1">Second comment with suggestions</comment>
            </review>
          RESPONSE
        end

        it 'creates valid <review> section only' do
          completion.execute

          diff_notes = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).reorder(:id)
          expect(diff_notes.count).to eq 2

          first_note = diff_notes[0]
          expect(first_note.note).to eq 'Second comment with suggestions'
          expect(first_note.position.new_line).to eq(1)
          second_note = diff_notes[1]
          expect(second_note.note).to eq 'First comment with suggestions'
          expect(second_note.position.new_line).to eq(2)
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
        let(:first_review_response) { {} }
        let(:second_review_response) { {} }

        it 'updates progress note with a success message' do
          completion.execute

          expect(merge_request.notes.count).to eq 1
          expect(merge_request.notes.last.note).to eq(described_class.no_comment_msg)
        end
      end

      context 'when review response are nil' do
        let(:first_review_response) { nil }
        let(:second_review_response) { nil }

        it 'updates progress note with a success message' do
          completion.execute

          expect(merge_request.notes.count).to eq 1
          expect(merge_request.notes.last.note).to eq(described_class.no_comment_msg)
        end
      end

      context 'when there were some comments' do
        context 'when an error gets raised' do
          before do
            allow(DraftNote).to receive(:new).and_raise('error')
          end

          it 'updates progress note with an error message' do
            completion.execute

            expect(merge_request.notes.non_diff_notes.last.note).to eq(described_class.error_msg)
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

            expect(merge_request.notes.count).to eq 4
            expect(merge_request.notes.diff_notes.count).to eq 3
            expect(merge_request.notes.non_diff_notes.last.note).to eq(described_class.error_msg)
          end
        end

        context 'when summary returned no result' do
          let(:summary_answer) { '' }

          it 'updates progress note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 4
            expect(merge_request.notes.diff_notes.count).to eq 3
            expect(merge_request.notes.non_diff_notes.last.note).to eq(described_class.error_msg)
          end
        end

        context 'when summary response is nil' do
          let(:summary_response) { nil }

          it 'updates progress note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 4
            expect(merge_request.notes.diff_notes.count).to eq 3
            expect(merge_request.notes.non_diff_notes.last.note).to eq(described_class.error_msg)
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

          expect(diff_notes[0].note).to eq 'Second comment with suggestions'
          expect(diff_notes[0].position.to_h).to eq({
            base_sha: diff_refs.base_sha,
            start_sha: diff_refs.start_sha,
            head_sha: diff_refs.head_sha,
            old_path: 'NEW.md',
            new_path: 'NEW.md',
            position_type: 'text',
            old_line: nil,
            new_line: 1,
            line_range: nil,
            ignore_whitespace_change: false
          })
        end
      end

      it 'calls UpdateReviewerStateService with review states' do
        expect_next_instance_of(
          MergeRequests::UpdateReviewerStateService,
          project: project, current_user: ::Users::Internal.duo_code_review_bot
        ) do |service|
          expect(service).to receive(:execute).with(merge_request, 'review_started')
          expect(service).to receive(:execute).with(merge_request, 'reviewed')
        end

        completion.execute
      end
    end

    context 'when the AI response is <review></review>' do
      let(:first_review_response) { { content: [{ text: ' <review></review> ' }] } }
      let(:second_review_response) { { content: [{ text: ' <review></review> ' }] } }
      let(:summary_response) { nil }

      it 'does not call DraftNote#new' do
        expect(DraftNote).not_to receive(:new)

        completion.execute
      end

      it 'does not raise an error' do
        expect { completion.execute }.not_to raise_error
      end
    end

    context 'when the chat client returns an unsuccessful response' do
      let(:first_review_response) { { error: { message: 'Error' } } }
      let(:second_review_response) { { error: { message: 'Error' } } }
      let(:summary_response) { nil }

      it 'does not call DraftNote#new' do
        expect(DraftNote).not_to receive(:new)

        completion.execute
      end
    end

    context 'when the AI response is empty' do
      let(:first_review_response) { {} }
      let(:second_review_response) { {} }
      let(:summary_response) { nil }

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
