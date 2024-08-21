# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::SummarizeComments::Prompts::AnthropicOld, feature_category: :duo_chat do
  let(:variables) do
    {
      notes_content: '<comment>foo</comment>'
    }
  end

  describe '.prompt' do
    it "returns prompt" do
      prompt = described_class.prompt(variables)

      expect(prompt[:messages]).to be_an(Array)

      expect(prompt[:system]).to be_a(String)
      expect(prompt[:system]).to eq(system_prompt_content)

      expect(prompt[:temperature]).to eq(described_class::TEMPERATURE)
    end

    it "calls with claude 3_5 sonnet model" do
      model = described_class.prompt(variables)[:model]

      expect(model).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET)
    end

    it "includes ExecutorOld prompts" do
      prompt = described_class.prompt(variables)

      expect(prompt[:messages]).to include(
        a_hash_including(
          role: :user,
          content: a_string_including("Each comment is wrapped in a <comment> tag.")
                    .and(a_string_including("<comment>foo</comment>"))
                    .and(a_string_including("Do not answer questions."))
        )
      )

      expect(prompt[:system]).to include(system_prompt_content)
    end
  end

  def system_prompt_content
    Gitlab::Llm::Chain::Tools::SummarizeComments::ExecutorOld::SYSTEM_PROMPT[1]
  end
end
