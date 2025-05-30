# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::ReviewMergeRequest, feature_category: :code_review_workflow do
  let(:review_prompt_class) { Gitlab::Llm::Templates::ReviewMergeRequest }
  let(:summary_prompt_class) { Gitlab::Llm::Templates::SummarizeReview }
  let(:tracking_context) { { action: :review_merge_request, request_id: 'uuid' } }
  let(:options) { { progress_note_id: progress_note.id } }
  let(:create_note_allowed?) { true }
  let(:prompt_version) { '1.0.0' }

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
      author: Users::Internal.duo_code_review_bot,
      system: true
    )
  end

  let(:review_prompt_message) do
    build(:ai_message, :review_merge_request, user: user, resource: merge_request, request_id: 'uuid')
  end

  subject(:completion) { described_class.new(review_prompt_message, review_prompt_class, options) }

  describe '#execute' do
    let(:combined_review_prompt) { { messages: ['This is the combined review prompt'] } }
    let(:summary_prompt) { { messages: ['This is a summary prompt'] } }

    let(:prompt_inputs) do
      {
        mr_title: 'MR Title',
        mr_description: 'MR Description',
        diff_lines: 'Diff lines',
        full_file_intro: 'Full file intro',
        full_content_section: 'Full content section'
      }
    end

    let(:diffs_and_paths) do
      {
        'UPDATED.md' => anything,
        'NEW.md' => anything
      }
    end

    before do
      stub_feature_flags(duo_code_review_claude_4_0_rollout: false)

      allow_next_instance_of(
        review_prompt_class,
        mr_title: merge_request.title,
        mr_description: merge_request.description,
        diffs_and_paths: kind_of(Hash),
        files_content: kind_of(Hash),
        user: user
      ) do |template|
        allow(template).to receive(:to_prompt_inputs).and_return(prompt_inputs)
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
          .with(summary_prompt)
          .and_return(summary_response&.to_json)
      end

      allow_next_instance_of(Gitlab::Llm::AiGateway::Client, user,
        service_name: :review_merge_request,
        tracking_context: tracking_context
      ) do |client|
        allow(client)
          .to receive(:complete_prompt)
          .with(
            base_url: Gitlab::AiGateway.url,
            prompt_name: :review_merge_request,
            inputs: prompt_inputs,
            model_metadata: nil,
            prompt_version: prompt_version
          )
          .and_return(
            instance_double(HTTParty::Response, body: combined_review_response.to_json, success?: true)
          )
      end
    end

    context 'when passing file contents to ai_prompt_class' do
      let(:combined_review_response) { '<review></review>' }
      let(:summary_response) { nil }
      let(:updated_file_content) { "existing line 1\nexisting line 2\n" }
      let(:updated_blob) { instance_double(Blob, data: updated_file_content) }
      let(:diff_files) do
        [
          instance_double(Gitlab::Diff::File,
            new_path: 'UPDATED.md',
            new_file?: false,
            old_path: 'UPDATED.md',
            old_blob: updated_blob,
            raw_diff: '@@ -1,2 +1,2 @@ existing line'),
          instance_double(Gitlab::Diff::File,
            new_path: 'NEW.md',
            new_file?: true,
            old_path: 'NEW.md',
            raw_diff: '@@ -0,0 +1,2 @@ new line')
        ]
      end

      before do
        # Setup reviewable files
        allow(merge_request).to receive(:ai_reviewable_diff_files).and_return(diff_files)

        allow_next_instance_of(Gitlab::Llm::Anthropic::Client, user,
          unit_primitive: 'review_merge_request',
          tracking_context: tracking_context
        ) do |client|
          allow(client).to receive(:messages_complete).and_return(combined_review_response)
        end

        allow_next_instance_of(Gitlab::Llm::AiGateway::Client, user,
          service_name: :review_merge_request,
          tracking_context: tracking_context
        ) do |client|
          allow(client)
            .to receive(:complete_prompt)
            .with(
              base_url: Gitlab::AiGateway.url,
              prompt_name: :review_merge_request,
              inputs: prompt_inputs,
              model_metadata: nil,
              prompt_version: prompt_version
            )
            .and_return(
              instance_double(HTTParty::Response, body: combined_review_response.to_json, success?: true)
            )
        end
      end

      it 'only includes original content of modified files (not new files)' do
        expect(review_prompt_class).to receive(:new).with(
          hash_including(
            mr_title: merge_request.title,
            mr_description: merge_request.description,
            files_content: { 'UPDATED.md' => updated_file_content }
          )
        ) do |args|
          expect(args[:files_content].keys).not_to include('NEW.md')

          instance_double(
            review_prompt_class,
            to_prompt_inputs: prompt_inputs
          )
        end

        completion.execute
      end
    end

    context 'when merge request has no reviewable files' do
      before do
        allow(merge_request).to receive(:ai_reviewable_diff_files).and_return([])
      end

      it 'creates a note with nothing to review message' do
        expect(completion).to receive(:update_progress_note).with(described_class.nothing_to_review_msg)

        completion.send(:perform_review)
      end
    end

    context 'when the chat client returns a successful response' do
      let(:combined_review_response) do
        <<~RESPONSE
          <review>
          <comment file="UPDATED.md" priority="3" old_line="" new_line="2">
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
          <comment file="NEW.md" priority="3" old_line="" new_line="1">Second comment with suggestions</comment>
          <comment file="NEW.md" priority="3" old_line="" new_line="2">Third comment with suggestions</comment>
          <comment file="NEW.md" priority="2" old_line="" new_line="2">Fourth comment with suggestions</comment>
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

      it 'destroys progress note' do
        completion.execute

        expect(Note.exists?(progress_note.id)).to be_falsey
      end

      it 'performs review and creates a note' do
        expect do
          completion.execute
        end.to change { merge_request.notes.diff_notes.count }.by(3)
          .and not_change { merge_request.notes.non_diff_notes.count }

        expect(merge_request.notes.non_diff_notes.last.note).to eq(summary_answer)
      end

      context 'when using claude_4_0 for duo code review' do
        let(:prompt_version) { '1.1.0' }

        before do
          stub_feature_flags(duo_code_review_claude_4_0_rollout: true)
        end

        # rubocop:disable RSpec/NoExpectationExample -- allow_next_instance_of Gitlab::Llm::AiGateway::Client
        # in before clause will do the check
        it 'successfully creates a note' do
          completion.execute
        end
        # rubocop:enable RSpec/NoExpectationExample
      end

      context 'when draft_notes is empty after mapping DraftNote objects' do
        let(:summary_response) { nil }
        let(:combined_review_response) do
          <<~RESPONSE
            <review>
            <comment file="UPDATED.md" priority="2" old_line="" new_line="2">High priority comment</comment>
            </review>
          RESPONSE
        end

        it 'updates progress note with no comment message and creates a todo' do
          expect_any_instance_of(TodoService) do |service|
            expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
          end

          completion.execute

          expect(merge_request.notes.diff_notes.count).to eq 0
          expect(merge_request.notes.non_diff_notes.last.note).to eq(described_class.no_comment_msg)
        end
      end

      context 'when draft_notes is empty after mapping DraftNote objects and no comments provided' do
        let(:summary_response) { nil }
        let(:combined_review_response) do
          <<~RESPONSE
          <review>
          1. Renaming the test category from "Govern" to "Software Supply Chain Security" across multiple test files
          </review>
          RESPONSE
        end

        it 'updates progress note with no comment message and creates a todo' do
          expect_any_instance_of(TodoService) do |service|
            expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
          end

          completion.execute

          expected_message = <<~RESPONSE.chomp
          #{described_class.no_comment_msg}

          1. Renaming the test category from "Govern" to "Software Supply Chain Security" across multiple test files
          RESPONSE
          expect(merge_request.notes.non_diff_notes.last.note).to eq(expected_message)
        end
      end

      context 'when review note already exists on the same position' do
        let(:progress_note2) do
          create(
            :note,
            note: 'progress note 2',
            project: project,
            noteable: merge_request,
            author: Users::Internal.duo_code_review_bot,
            system: true
          )
        end

        before do
          described_class.new(review_prompt_message, review_prompt_class, progress_note_id: progress_note2.id).execute
        end

        it 'does not add more notes to the same position' do
          expect { completion.execute }
            .to not_change { merge_request.notes.diff_notes.count }
            .and not_change { merge_request.notes.non_diff_notes.count }

          expect(merge_request.notes.non_diff_notes.last.note).to eq(described_class.no_comment_msg)
        end
      end

      context 'when resource is empty' do
        let(:review_prompt_message) do
          build(:ai_message, :review_merge_request, user: user, resource: nil, request_id: 'uuid')
        end

        it 'creates a note and return' do
          expect do
            described_class.new(review_prompt_message, review_prompt_class, options).execute
          end.to not_change { merge_request.notes.diff_notes.count }
            .and not_change { merge_request.notes.non_diff_notes.count }

          expect(merge_request.notes.non_diff_notes.last.note).to eq(described_class.resource_not_found_msg)
        end
      end

      context 'when progress note is not provided' do
        let(:options) { {} }

        it 'creates progress note and finish review as expected' do
          expect do
            completion.execute
          end.to change { merge_request.notes.diff_notes.count }.by(3)
            .and change { merge_request.notes.non_diff_notes.count }.by(1)

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
        let(:combined_review_response) do
          <<~RESPONSE
            <review>
            <comment file="UPDATED.md">First comment with suggestions</comment>
            <comment file="UPDATED.md" priority="3" old_line="" new_line="2">Second comment with suggestions</comment>
            <comment file="NEW.md" priority="" old_line="" new_line="1">Third comment with no priority</comment>
            <comment file="NEW.md" priority="3" old_line="" new_line="">Fourth comment with missing lines</comment>
            <comment file="NEW.md" priority="3" old_line="" new_line="10">Fifth comment with invalid line</comment>
            </review>
          RESPONSE
        end

        it 'creates a valid comment only' do
          completion.execute

          diff_note = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).sole

          expect(diff_note.note).to eq 'Second comment with suggestions'
          expect(diff_note.position.new_line).to eq(2)
        end

        context 'when the exact line could not be found' do
          let(:combined_review_response) do
            <<~RESPONSE
            <review>
            <comment file="UPDATED.md" priority="3" old_line="2" new_line="2">Second comment with suggestions</comment>
            </review>
            RESPONSE
          end

          it 'matches it using new_line only' do
            completion.execute

            diff_note = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).sole

            expect(diff_note.note).to eq 'Second comment with suggestions'
            expect(diff_note.position.new_line).to eq(2)
          end
        end
      end

      context 'when the chat client decides to return contents outside of <review> tag' do
        let(:combined_review_response) do
          <<~RESPONSE
            Let me explain how awesome this review is.
            <review>
            <comment file="UPDATED.md" priority="3" old_line="" new_line="2">First comment with suggestions</comment>
            <comment file="NEW.md" priority="3" old_line="" new_line="1">Second comment with suggestions</comment>
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

      context 'when there were no comments' do
        let(:combined_review_response) { {} }

        it 'creates a note with a success message' do
          completion.execute

          expect(merge_request.notes.count).to eq 1
          expect(merge_request.notes.last.note).to eq(described_class.no_comment_msg)
        end

        it 'creates a new todo' do
          expect_any_instance_of(TodoService) do |service|
            expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
          end

          completion.execute
        end
      end

      context 'when review response is blank' do
        let(:combined_review_response) { '' }

        it 'creates a note with a success message' do
          completion.execute

          expect(merge_request.notes.count).to eq 1
          expect(merge_request.notes.last.note).to eq(described_class.no_comment_msg)
        end

        it 'creates a new todo' do
          expect_any_instance_of(TodoService) do |service|
            expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
          end

          completion.execute
        end
      end

      context 'when there were some comments' do
        context 'when an error gets raised' do
          before do
            allow(DraftNote).to receive(:new).and_raise('error')
          end

          it 'creates a note with an error message' do
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

          it 'creates a note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 4
            expect(merge_request.notes.diff_notes.count).to eq 3
            expect(merge_request.notes.non_diff_notes.last.note).to eq(described_class.error_msg)
          end
        end

        context 'when summary returned no result' do
          let(:summary_answer) { '' }

          it 'creates a note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 4
            expect(merge_request.notes.diff_notes.count).to eq 3
            expect(merge_request.notes.non_diff_notes.last.note).to eq(described_class.error_msg)
          end
        end

        context 'when summary response is nil' do
          let(:summary_response) { nil }

          it 'creates a note with an error message' do
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

      context 'when there is an error due of large prompt' do
        let(:summary_response) { nil }
        let(:retry_response) { { "content" => [{ "text" => "<review></review>" }] } }

        let(:example_error_response) do
          instance_double(HTTParty::Response, body: %(Some error).to_json, success?: false)
        end

        let(:example_retry_response) do
          instance_double(HTTParty::Response, body: retry_response.to_json, success?: true)
        end

        before do
          allow(Gitlab::AppLogger).to receive(:info)
        end

        it 'regenerates the prompt without file content' do
          # We expect that a new prompt is generated with `files_content` as empty hash when we retry.
          expect_next_instance_of(
            review_prompt_class,
            hash_including(
              files_content: {}
            )
          ) do |template|
            expect(template).to receive(:to_prompt_inputs).and_return(prompt_inputs)
          end

          allow_next_instance_of(
            Gitlab::Llm::AiGateway::Client,
            user,
            service_name: :review_merge_request,
            tracking_context: tracking_context
          ) do |client|
            expect(client)
              .to receive(:complete_prompt)
              .with(
                base_url: Gitlab::AiGateway.url,
                prompt_name: :review_merge_request,
                inputs: kind_of(Hash),
                model_metadata: nil,
                prompt_version: prompt_version
              )
              .and_return(example_error_response)

            # On retry, AiGateway client instantiated separately, instead of reusing the same instance.
            allow_next_instance_of(
              Gitlab::Llm::AiGateway::Client,
              user,
              service_name: :review_merge_request,
              tracking_context: tracking_context
            ) do |client2|
              expect(client2)
                .to receive(:complete_prompt)
                .with(
                  base_url: Gitlab::AiGateway.url,
                  prompt_name: :review_merge_request,
                  inputs: kind_of(Hash),
                  model_metadata: nil,
                  prompt_version: prompt_version
                )
                .and_return(example_retry_response)
            end
          end

          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: "Review request failed with files content, retrying without file content",
              event: "review_merge_request_retry_without_content",
              merge_request_id: merge_request&.id,
              error: ["An unexpected error has occurred."]
            )
          )

          completion.execute
        end
      end
    end

    context 'when the AI response is <review></review>' do
      let(:combined_review_response) { ' <review></review> ' }
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
      let(:combined_review_response) { { detail: 'Error' } }
      let(:summary_response) { nil }

      it 'does not call DraftNote#new' do
        expect(DraftNote).not_to receive(:new)

        completion.execute
      end
    end

    context 'when the AI response is empty' do
      let(:combined_review_response) { {} }
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
