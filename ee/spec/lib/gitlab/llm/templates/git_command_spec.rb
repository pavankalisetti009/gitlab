# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::GitCommand, feature_category: :code_review_workflow do
  describe '#to_prompt' do
    let(:given_prompt) { 'list last 10 commit titles' }
    let(:prompt) { described_class.new(given_prompt).to_prompt }

    subject(:user_prompt) { prompt&.dig(:messages, 0, :content) }

    it 'includes given prompt' do
      expect(user_prompt).to include(given_prompt)
    end

    it 'uses Claude 3 Haiku' do
      expect(prompt[:model]).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_HAIKU)
    end

    it 'specifies the system prompt' do
      expect(prompt[:system]).to eq(described_class::SYSTEM_MESSAGE[1])
    end
  end
end
