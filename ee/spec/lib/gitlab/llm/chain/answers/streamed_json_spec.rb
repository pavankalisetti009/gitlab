# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Answers::StreamedJson, feature_category: :duo_chat do
  describe "#next_chunk" do
    subject { described_class.new.next_chunk(chunk) }

    context "when stream is empty" do
      let(:chunk) { "" }

      it 'returns nil' do
        is_expected.to be_nil
      end
    end

    context "when stream does not contain the final answer" do
      let(:chunk) { create(:action_chunk) }

      it 'returns nil' do
        is_expected.to be_nil
      end
    end

    context "when streaming beginning of the answer" do
      let(:chunk) { create(:final_answer_chunk, chunk: "I") }

      it 'returns stream payload' do
        is_expected.to eq({ id: 1, content: "I" })
      end
    end

    context "when streaming multiple chunks of final answer" do
      let(:chunk) { create(:final_answer_multi_chunk, chunks: ["Hello", " there"]) }

      it 'returns stream payload' do
        is_expected.to eq({ id: 1, content: "Hello there" })
      end
    end
  end
end
