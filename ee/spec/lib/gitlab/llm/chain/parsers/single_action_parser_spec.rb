# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Parsers::SingleActionParser, feature_category: :duo_chat do
  describe "#parse" do
    let(:parser) { described_class.new(output: output) }

    before do
      parser.parse
    end

    context "with final answer" do
      let(:output) { create(:final_answer_multi_chunk, chunks: ["To", " perform", " a", " Git", " re", "base"]) }

      it "returns only the final answer" do
        expect(parser.action).to be_nil
        expect(parser.action_input).to be_nil
        expect(parser.thought).to be_nil
        expect(parser.final_answer).to eq("To perform a Git rebase")
      end
    end

    context "with chosen action" do
      let(:output) { create(:action_chunk, thought: "thought", tool: "issue_reader", tool_input: "input") }

      it "returns the action" do
        expect(parser.action).to eq("IssueReader")
        expect(parser.action_input).to eq("input")
        expect(parser.thought).to eq("thought")
        expect(parser.final_answer).to be_nil
      end
    end

    context "with no output" do
      let(:output) { nil }

      it "returns nil" do
        expect(parser.action).to be_nil
        expect(parser.final_answer).to be_nil
      end
    end

    context "with empty output" do
      let(:output) { "" }

      it "returns nil" do
        expect(parser.action).to be_nil
        expect(parser.final_answer).to be_nil
      end
    end
  end
end
