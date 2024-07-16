# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Completions::ReviewMergeRequest, feature_category: :code_review_workflow do
  let(:review_prompt_class) { Gitlab::Llm::Templates::ReviewMergeRequest }
  let(:summary_prompt_class) { Gitlab::Llm::Templates::SummarizeReview }
  let(:tracking_context) { { action: :review_merge_request, request_id: 'uuid' } }
  let(:options) { {} }
  let(:response_modifier) { double }
  let(:create_note_allowed?) { true }
  let_it_be(:duo_code_review_bot) { create(:user, :duo_code_review_bot) }
  let_it_be(:merge_request) { create(:merge_request) }
  let_it_be(:user) { create(:user, developer_of: merge_request.project) }
  let_it_be(:diff_refs) { merge_request.diff_refs }

  let(:ai_reviewable_diff_files) do
    [
      instance_double(
        Gitlab::Diff::File,
        old_path: 'NEW.md',
        new_path: 'NEW.md',
        diff_lines_by_hunk: [
          {
            added: [
              instance_double(Gitlab::Diff::Line, old_pos: 5, new_pos: 3),
              instance_double(Gitlab::Diff::Line, old_pos: 5, new_pos: 4)
            ],
            removed: [
              instance_double(Gitlab::Diff::Line, old_pos: 3, new_pos: 3),
              instance_double(Gitlab::Diff::Line, old_pos: 4, new_pos: 3)
            ]
          }
        ]
      ),
      instance_double(
        Gitlab::Diff::File,
        old_path: 'UPDATED.md',
        new_path: 'UPDATED.md',
        diff_lines_by_hunk: [
          {
            added: [],
            removed: [
              instance_double(Gitlab::Diff::Line, old_pos: 3, new_pos: 3),
              instance_double(Gitlab::Diff::Line, old_pos: 4, new_pos: 3)
            ]
          }
        ]
      )
    ]
  end

  let(:review_prompt_message) do
    build(:ai_message, :review_merge_request, user: user, resource: merge_request, request_id: 'uuid')
  end

  subject(:completion) { described_class.new(review_prompt_message, review_prompt_class, options) }

  before do
    allow(merge_request)
      .to receive(:ai_reviewable_diff_files)
      .and_return(ai_reviewable_diff_files)
  end

  describe '#execute' do
    let(:review_prompt) { 'This is a review prompt' }
    let(:summary_prompt) { 'This is a summary prompt' }
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

      allow(::Gitlab::Llm::VertexAi::Configuration)
        .to receive(:payload_parameters)
        .with(temperature: 0)
        .and_return(payload_parameters)

      allow_next_instance_of(Gitlab::Llm::VertexAi::Client, user,
        unit_primitive: 'review_merge_request',
        tracking_context: tracking_context
      ) do |client|
        allow(client)
          .to receive(:chat)
          .with(content: review_prompt, parameters: payload_parameters)
          .and_return(review_response.to_json)
      end

      allow_next_instance_of(Gitlab::Llm::VertexAi::Client, user,
        unit_primitive: 'summarize_review',
        tracking_context: tracking_context
      ) do |client|
        allow(client)
          .to receive(:text)
          .with(content: summary_prompt)
          .and_return(summary_response.to_json)
      end
    end

    context 'when generated review prompt is nil' do
      let(:review_prompt) { nil }

      it 'does not make a request to AI provider' do
        expect(Gitlab::Llm::VertexAi::Client).not_to receive(:new)

        completion.execute
      end
    end

    context 'when the chat client returns a successful response' do
      let(:review_answer) { 'Helpful review with suggestions' }
      let(:review_response) do
        {
          "predictions" => [
            {
              "content" => review_answer,
              "safetyAttributes" => {
                "categories" => ["Violent"],
                "scores" => [0.4000000059604645],
                "blocked" => false
              }
            }
          ]
        }
      end

      let(:summary_answer) { 'Helpful review summary' }
      let(:summary_response) do
        {
          "predictions" => [
            {
              "content" => summary_answer
            }
          ]
        }
      end

      it 'builds draft note and publish to create diff note on new and updated files' do
        new_file_draft_note_params = {
          merge_request: merge_request,
          author: duo_code_review_bot,
          note: review_answer,
          position: {
            base_sha: diff_refs.base_sha,
            start_sha: diff_refs.start_sha,
            head_sha: diff_refs.head_sha,
            old_path: 'NEW.md',
            new_path: 'NEW.md',
            position_type: 'text',
            old_line: nil,
            new_line: 4,
            ignore_whitespace_change: false
          }
        }

        updated_file_draft_note_params = {
          merge_request: merge_request,
          author: duo_code_review_bot,
          note: review_answer,
          position: {
            base_sha: diff_refs.base_sha,
            start_sha: diff_refs.start_sha,
            head_sha: diff_refs.head_sha,
            old_path: 'UPDATED.md',
            new_path: 'UPDATED.md',
            position_type: 'text',
            old_line: 4,
            new_line: nil,
            ignore_whitespace_change: false
          }
        }

        draft_note_1 = instance_double(DraftNote)
        draft_note_2 = instance_double(DraftNote)

        expect(DraftNote).to receive(:new).with(new_file_draft_note_params).and_return(draft_note_1)
        expect(DraftNote).to receive(:new).with(updated_file_draft_note_params).and_return(draft_note_2)
        expect(DraftNote).to receive(:bulk_insert!).with([draft_note_1, draft_note_2], batch_size: 20)
        expect_next_instance_of(
          DraftNotes::PublishService,
          merge_request,
          duo_code_review_bot
        ) do |svc|
          expect(svc).to receive(:execute).with(executing_user: user)
        end

        completion.execute
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

          expect(Note.count).to eq 1
          expect(Note.last.note).to eq s_("DuoCodeReview|I finished my review and found nothing to comment on. " \
            "Nice work! :tada:")
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
              note: s_("MergeRequests|Hey :wave: I'm starting to review your merge request and " \
                "I will let you know when I'm finished.")
            ).and_call_original
            allow(Notes::CreateService).to receive(:new).and_call_original

            completion.execute

            expect(Note.last.note).to eq s_("Helpful review summary")
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

            expect(Note.count).to eq 1
            expect(Note.last.note).to eq s_("DuoCodeReview|I have encountered some issues while I was reviewing. " \
              "Please try again later.")
          end
        end

        context 'when summary returned no result' do
          let(:summary_answer) { '' }

          it 'updates progress note with an error message' do
            completion.execute

            expect(Note.count).to eq 1
            expect(Note.last.note).to eq s_("DuoCodeReview|I have encountered some issues while I was reviewing. " \
              "Please try again later.")
          end
        end
      end

      context 'when draft notes limit is reached' do
        before do
          stub_const("#{described_class}::DRAFT_NOTES_COUNT_LIMIT", 1)
        end

        it 'builds draft note and publish to create diff note on new and updated files' do
          new_file_draft_note_params = {
            merge_request: merge_request,
            author: duo_code_review_bot,
            note: review_answer,
            position: {
              base_sha: diff_refs.base_sha,
              start_sha: diff_refs.start_sha,
              head_sha: diff_refs.head_sha,
              old_path: 'NEW.md',
              new_path: 'NEW.md',
              position_type: 'text',
              old_line: nil,
              new_line: 4,
              ignore_whitespace_change: false
            }
          }

          draft_note_1 = instance_double(DraftNote)

          expect(DraftNote).to receive(:new).with(new_file_draft_note_params).and_return(draft_note_1)
          expect(DraftNote).to receive(:bulk_insert!).with([draft_note_1], batch_size: 20)
          expect_next_instance_of(
            DraftNotes::PublishService,
            merge_request,
            duo_code_review_bot
          ) do |svc|
            expect(svc).to receive(:execute).with(executing_user: user)
          end

          completion.execute
        end
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
