# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::ReviewMergeRequest, feature_category: :code_review_workflow do
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

  describe '#to_prompt' do
    let(:prompt) do
      described_class.new(
        mr_title: mr_title,
        mr_description: mr_description,
        diffs_and_paths: diffs_and_paths,
        files_content: files_content,
        user: user
      ).to_prompt
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

    subject(:user_prompt) { prompt&.dig(:messages, 0, :content) }

    it 'includes merge request title' do
      expect(user_prompt).to include('Fix typos in welcome message')
    end

    it 'includes merge request description' do
      expect(user_prompt).to include('Improving readability by fixing typos and adding proper punctuation.')
    end

    it 'uses Claude 3.7 Sonnet' do
      expect(prompt[:model]).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_7_SONNET)
    end

    it 'specifies the system prompt' do
      expect(prompt[:system]).to eq(described_class::SYSTEM_MESSAGE[1])
    end

    it 'specifies max_tokens' do
      expect(prompt[:max_tokens]).to eq(described_class::OUTPUT_MAX_TOKENS)
    end

    it 'specifies timeout' do
      expect(prompt[:timeout]).to eq(described_class::TIMEOUT)
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

  describe '#to_prompt_inputs' do
    let(:expected_diff_lines) do
      <<~DIFF.chomp
        <file_diff filename="UPDATED.md">
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
        </file_diff>
      DIFF
    end

    let(:expected_full_file_intro) do
      " You will also be provided with the original content of modified files (before changes). " \
        "Newly added files are not included as their full content is already in the diffs."
    end

    let(:expected_full_content_section) do
      <<~CONTENT.chomp
        Original file content (before changes):

        Check for code duplication, redundancies, and inconsistencies.

        <full_file filename="UPDATED.md">
        @@ -1,4 +1,4 @@
         # UPDATED
        -Welcome
        -This is an updated file
        +Welcome!
        +This is an updated file.
        </full_file>
      CONTENT
    end

    subject(:prompt_inputs) do
      described_class.new(
        mr_title: mr_title,
        mr_description: mr_description,
        diffs_and_paths: diffs_and_paths,
        files_content: files_content,
        user: user
      ).to_prompt_inputs
    end

    shared_examples 'builds prompt inputs' do
      it 'returns prompt inputs' do
        expect(prompt_inputs).to eq({
          mr_title: mr_title,
          mr_description: mr_description,
          diff_lines: expected_diff_lines,
          full_file_intro: expected_full_file_intro,
          full_content_section: expected_full_content_section
        })
      end
    end

    it_behaves_like 'builds prompt inputs'

    context 'when files_content is empty' do
      let(:files_content) { {} }
      let(:expected_full_file_intro) { '' }
      let(:expected_full_content_section) { '' }

      it_behaves_like 'builds prompt inputs'
    end

    context 'when duo_code_review_full_file feature flag disabled' do
      let(:expected_full_file_intro) { '' }
      let(:expected_full_content_section) { '' }

      before do
        stub_feature_flags(duo_code_review_full_file: false)
      end

      it_behaves_like 'builds prompt inputs'
    end

    context 'with multiple files' do
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

      let(:expected_diff_lines) do
        <<~DIFF.chomp
          <file_diff filename="UPDATED.md">
          <line type="context" old_line="1" new_line="1"># UPDATED</line>
          <line type="deleted" old_line="2" new_line="">Welcome</line>
          <line type="deleted" old_line="3" new_line="">This is an updated file</line>
          <line type="added" old_line="" new_line="2">Welcome!</line>
          <line type="added" old_line="" new_line="3">This is an updated file.</line>
          </file_diff>

          <file_diff filename="OTHER.md">
          <chunk_header>@@ -5,3 +5,3 @@</chunk_header>
          <line type="context" old_line="5" new_line="5"># CONTENT</line>
          <line type="deleted" old_line="6" new_line="">This is old content</line>
          <line type="added" old_line="" new_line="6">This is updated content</line>
          </file_diff>
        DIFF
      end

      let(:expected_full_content_section) do
        <<~CONTENT.chomp
          Original file content (before changes):

          Check for code duplication, redundancies, and inconsistencies.

          <full_file filename="UPDATED.md">
          # UPDATED
          Welcome!
          This is an updated file.

          ...
          </full_file>

          <full_file filename="OTHER.md">
          Some header

          ...

          # CONTENT

          This is updated content
          </full_file>
        CONTENT
      end

      it_behaves_like 'builds prompt inputs'
    end
  end
end
