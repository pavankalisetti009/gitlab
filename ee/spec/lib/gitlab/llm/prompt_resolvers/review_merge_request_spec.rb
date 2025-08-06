# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::PromptResolvers::ReviewMergeRequest, feature_category: :code_review_workflow do
  describe '.execute' do
    subject(:prompt_version) { described_class.execute(user: user, group: group) }

    let(:user) { build_stubbed(:user) }
    let(:group) { build_stubbed(:group) }

    before do
      stub_feature_flags(use_claude_code_completion: false)
      stub_feature_flags(duo_code_review_prompt_updates: false)
      stub_feature_flags(duo_code_review_custom_instructions: false)
      stub_feature_flags(duo_code_review_claude_4_0_rollout: false)
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(false)
    end

    context 'when use_claude_code_completion is enabled' do
      before do
        stub_feature_flags(use_claude_code_completion: true)
      end

      it 'returns the correct prompt version for Claude 3.5 Sonnet' do
        expect(prompt_version).to eq('0.9.0')
      end
    end

    context 'when duo_code_review_prompt_updates is enabled' do
      before do
        stub_feature_flags(duo_code_review_prompt_updates: true)
      end

      it 'returns the correct prompt version for Claude 4.0 Sonnet with major prompt updates' do
        expect(prompt_version).to eq('1.3.0')
      end
    end

    context 'when amazon_q is enabled' do
      before do
        allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)
      end

      it 'returns the correct prompt version for Amazon Q' do
        expect(prompt_version).to eq('amazon_q/1.0.0')
      end
    end

    context 'when duo_code_review_custom_instructions is enabled' do
      before do
        stub_feature_flags(duo_code_review_custom_instructions: true)
      end

      it 'returns the correct prompt version for Claude 4.0 Sonnet with custom instructions' do
        expect(prompt_version).to eq('1.2.0')
      end
    end

    context 'when duo_code_review_claude_4_0_rollout is enabled' do
      before do
        stub_feature_flags(duo_code_review_claude_4_0_rollout: true)
      end

      it 'returns the correct prompt version for Claude 4.0 Sonnet' do
        expect(prompt_version).to eq('1.1.0')
      end
    end

    context 'when no specific feature flags are enabled' do
      it 'returns the default prompt version for Claude 3.7 Sonnet' do
        expect(prompt_version).to eq('1.0.0')
      end
    end
  end
end
