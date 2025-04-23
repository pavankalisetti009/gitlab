# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::ReviewMergeRequest, feature_category: :code_review_workflow do
  describe '#to_prompt' do
    let(:diffs_and_paths) do
      {
        'NEW.md' => <<~RAWDIFF
        @@ -1,4 +1,4 @@
         # NEW

        -Welcome
        -This is a new file
        +Welcome!
        +This is a new file.
        @@ -10,3 +10,3 @@
         # ANOTHER HUNK

        -This is an old line
        +This is a new line
        RAWDIFF
      }
    end

    let(:new_path) { 'NEW.md' }
    let(:user) { build(:user) }
    let(:mr_title) { 'Fix typos in welcome message' }
    let(:mr_description) { 'Improving readability by fixing typos and adding proper punctuation.' }

    let(:prompt) do
      described_class.new(
        mr_title: mr_title,
        mr_description: mr_description,
        diffs_and_paths: diffs_and_paths,
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
         <line type="context" old_line="1" new_line="1"># NEW</line>
         <line type="context" old_line="2" new_line="2"></line>
         <line type="deleted" old_line="3" new_line="">Welcome</line>
         <line type="deleted" old_line="4" new_line="">This is a new file</line>
         <line type="added" old_line="" new_line="3">Welcome!</line>
         <line type="added" old_line="" new_line="4">This is a new file.</line>
         <chunk_header>@@ -10,3 +10,3 @@</chunk_header>
         <line type="context" old_line="10" new_line="10"># ANOTHER HUNK</line>
         <line type="context" old_line="11" new_line="11"></line>
         <line type="deleted" old_line="12" new_line="">This is an old line</line>
         <line type="added" old_line="" new_line="12">This is a new line</line>
        CONTENT
      )
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

    context 'with multiple files' do
      before do
        stub_feature_flags(duo_code_review_multi_file: true)
      end

      let(:diffs_and_paths) do
        {
          'NEW.md' => "@@ -1,4 +1,4 @@\n # NEW\n-Welcome\n-This is a new file\n+Welcome!\n+This is a new file.",
          'OTHER.md' => "@@ -5,3 +5,3 @@\n # CONTENT\n-This is old content\n+This is updated content"
        }
      end

      it 'includes both file diffs' do
        expect(user_prompt).to include('<file_diff filename="NEW.md">')
        expect(user_prompt).to include('<file_diff filename="OTHER.md">')
      end

      it 'includes content from both files' do
        # First file content
        expect(user_prompt).to include('Welcome')
        expect(user_prompt).to include('Welcome!')

        # Second file content
        expect(user_prompt).to include('This is old content')
        expect(user_prompt).to include('This is updated content')
      end
    end
  end
end
