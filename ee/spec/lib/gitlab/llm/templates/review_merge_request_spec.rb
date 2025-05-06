# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::ReviewMergeRequest, feature_category: :code_review_workflow do
  describe '#to_prompt' do
    let(:diffs_and_paths) do
      {
        'UPDATED.md' => <<~RAWDIFF
        @@ -1,4 +1,4 @@
         # UPDATED

        -Welcome
        -This is an updated file
        +Welcome!
        +This is an updated file.
        @@ -10,3 +10,3 @@
         # ANOTHER HUNK

        -This is an old line
        +This is a new line
        RAWDIFF
      }
    end

    let(:new_path) { 'UPDATED.md' }
    let(:user) { build(:user) }
    let(:mr_title) { 'Fix typos in welcome message' }
    let(:mr_description) { 'Improving readability by fixing typos and adding proper punctuation.' }
    let(:files_content) do
      {
        'UPDATED.md' =>
          "@@ -1,4 +1,4 @@\n # UPDATED\n-Welcome\n-This is an updated file\n+Welcome!\n+This is an updated file."
      }
    end

    let(:prompt) do
      described_class.new(
        mr_title: mr_title,
        mr_description: mr_description,
        diffs_and_paths: diffs_and_paths,
        files_content: files_content,
        user: user
      ).to_prompt
    end

    subject(:user_prompt) { prompt&.dig(:messages, 0, :content) }

    before do
      stub_feature_flags(duo_code_review_multi_file: false)
    end

    it 'includes new_path' do
      expect(user_prompt).to include("<filename>\n#{new_path}\n</filename>")
    end

    it 'includes merge request title' do
      expect(user_prompt).to include('Fix typos in welcome message')
    end

    it 'includes merge request description' do
      expect(user_prompt).to include('Improving readability by fixing typos and adding proper punctuation.')
    end

    it 'includes diff lines with hunk header' do
      expect(user_prompt).to include(
        <<~CONTENT
         <line type="context" old_line="1" new_line="1"># UPDATED</line>
         <line type="context" old_line="2" new_line="2"></line>
         <line type="deleted" old_line="3" new_line="">Welcome</line>
         <line type="deleted" old_line="4" new_line="">This is an updated file</line>
         <line type="added" old_line="" new_line="3">Welcome!</line>
         <line type="added" old_line="" new_line="4">This is an updated file.</line>
         <chunk_header>@@ -10,3 +10,3 @@</chunk_header>
         <line type="context" old_line="10" new_line="10"># ANOTHER HUNK</line>
         <line type="context" old_line="11" new_line="11"></line>
         <line type="deleted" old_line="12" new_line="">This is an old line</line>
         <line type="added" old_line="" new_line="12">This is a new line</line>
        CONTENT
      )
    end

    context 'when duo_code_review_full_file feature flag is enabled' do
      it 'includes the original file content introduction text' do
        expect(user_prompt).to include("You will also be provided with the original content of modified files " \
          "(before changes). Newly added files are not included as their full content is already in the diffs.")
      end

      it 'includes the original file content' do
        expect(user_prompt).to include("<full_file filename=\"#{new_path}\">")
        expect(user_prompt).to include(files_content['UPDATED.md'])
      end
    end

    context 'when duo_code_review_full_file feature flag is disabled' do
      before do
        stub_feature_flags(duo_code_review_full_file: false)
      end

      it 'does not include the full file content introduction text' do
        expect(user_prompt).not_to include("You will also be provided with the original content of modified files " \
          "(before changes).")
      end

      it 'does not include the full file content' do
        expect(user_prompt).not_to include("<full_file_content>\n#{files_content['UPDATED.md']}\n</full_file_content>")
      end
    end

    it 'uses Claude 3.7 Sonnet' do
      expect(prompt[:model]).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_7_SONNET)
    end

    context 'when duo_code_review_claude_3_7_sonnet FF is disabled' do
      before do
        stub_feature_flags(duo_code_review_claude_3_7_sonnet: false)
      end

      it 'uses Claude 3.5 Sonnet' do
        expect(prompt[:model]).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET)
      end
    end

    it 'specifies the system prompt' do
      expect(prompt[:system]).to eq(described_class::SYSTEM_MESSAGE[1])
    end

    it 'specifies max_tokens' do
      expect(prompt[:max_tokens]).to eq(described_class::OUTPUT_MAX_TOKENS)
    end

    context 'with multiple files' do
      before do
        stub_feature_flags(duo_code_review_multi_file: true)
      end

      let(:diffs_and_paths) do
        {
          'UPDATED.md' =>
          "@@ -1,4 +1,4 @@\n # UPDATED\n-Welcome\n-This is an updated file\n+Welcome!\n+This is an updated file.",
          'OTHER.md' => "@@ -5,3 +5,3 @@\n # CONTENT\n-This is old content\n+This is updated content"
        }
      end

      let(:files_content) do
        {
          'UPDATED.md' => "# UPDATED\nWelcome!\nThis is an updated file.\n\n...",
          'OTHER.md' => "Some header\n\n...\n\n# CONTENT\n\nThis is updated content"
        }
      end

      it 'includes both file diffs' do
        expect(user_prompt).to include('<file_diff filename="UPDATED.md">')
        expect(user_prompt).to include('<file_diff filename="OTHER.md">')
      end

      it 'includes content from both files' do
        # First file content
        expect(user_prompt).to include('Welcome')
        expect(user_prompt).to include('This is an updated file')
        expect(user_prompt).to include('This is an updated file.')

        # Second file content
        expect(user_prompt).to include('This is old content')
        expect(user_prompt).to include('This is updated content')
      end

      context 'when duo_code_review_full_file feature flag is enabled' do
        it 'includes the original file content introduction text' do
          expect(user_prompt).to include("You will also be provided with the original content of modified files " \
            "(before changes). Newly added files are not included as their full content is already in the diffs.")
        end

        it 'includes content for modified files' do
          expect(user_prompt).to include('<full_file filename="UPDATED.md">')
          expect(user_prompt).to include('<full_file filename="OTHER.md">')
          expect(user_prompt).to include(files_content['UPDATED.md'])
          expect(user_prompt).to include(files_content['OTHER.md'])
        end

        it 'formats file contents correctly' do
          expected_format = files_content.map do |path, content|
            %(<full_file filename="#{path}">\n#{content}\n</full_file>)
          end.join("\n\n")
          expect(user_prompt).to include(expected_format)
        end
      end

      context 'when duo_code_review_full_file feature flag is disabled' do
        before do
          stub_feature_flags(duo_code_review_full_file: false)
        end

        it 'does not include the full file content introduction text' do
          expect(user_prompt).not_to include("You will also be provided with the original content of the file(s)")
        end

        it 'does not include full content for the files' do
          expect(user_prompt).not_to include('<full_file filename="UPDATED.md">')
          expect(user_prompt).not_to include('<full_file filename="OTHER.md">')
        end
      end
    end
  end
end
