# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::ReviewMergeRequest, feature_category: :code_review_workflow do
  describe '#to_prompt' do
    let(:diff) { "@@ -1,4 +1,4 @@\n # NEW\n \n-Welcome\n-This is a new file\n+Welcome!\n+This is a new file." }
    let(:new_path) { 'NEW.md' }
    let(:hunk) { '-Welcome\n-This is a new file+Welcome!\n+This is a new file.' }

    subject(:prompt) { described_class.new(new_path, diff, hunk).to_prompt }

    it 'includes new_path' do
      expect(prompt).to include(new_path)
    end

    it 'includes diff' do
      expect(prompt).to include(" # NEW\n \n-Welcome\n-This is a new file\n+Welcome!\n+This is a new file.")
    end

    it 'does not include git diff prefix' do
      expect(prompt).not_to include('@@ -1,4 +1,4 @@')
    end

    it 'includes hunk' do
      expect(prompt).to include(hunk)
    end

    context 'when diff is blank' do
      let(:diff) { '' }

      it 'returns nil' do
        expect(prompt).to be_nil
      end
    end
  end
end
