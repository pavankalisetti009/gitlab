# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::ReviewMergeRequest, feature_category: :code_review_workflow do
  describe '#to_prompt' do
    let(:diff) do
      <<~RAWDIFF
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
    end

    let(:new_path) { 'NEW.md' }
    let(:hunk) { '-Welcome\n-This is a new file+Welcome!\n+This is a new file.' }
    let(:user) { build(:user) }
    let(:prompt) { described_class.new(new_path, diff, hunk, user).to_prompt }

    subject(:user_prompt) { prompt&.dig(:messages, 0, :content) }

    it 'includes new_path' do
      expect(user_prompt).to include(new_path)
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
  end
end
