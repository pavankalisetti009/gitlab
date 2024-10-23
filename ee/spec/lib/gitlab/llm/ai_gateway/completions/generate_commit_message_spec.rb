# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::GenerateCommitMessage, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:merge_request) { create(:merge_request) }

  let(:template_class) { ::Gitlab::Llm::Templates::GenerateCommitMessage }
  let(:ai_options) { {} }
  let(:ai_client) { instance_double(Gitlab::Llm::AiGateway::Client) }
  let(:ai_response) { instance_double(HTTParty::Response, body: %("Success"), success?: true) }
  let(:uuid) { SecureRandom.uuid }
  let(:prompt_message) do
    build(:ai_message, :generate_commit_message, user: user, resource: merge_request, request_id: uuid)
  end

  let(:tracking_context) { { action: :generate_commit_message, request_id: uuid } }

  subject(:generate_commit_message) { described_class.new(prompt_message, template_class, ai_options).execute }

  describe "#execute" do
    before do
      allow(Gitlab::Llm::AiGateway::Client).to receive(:new).and_return(ai_client)
    end

    it 'executes a completion request and calls the response chains' do
      expect(Gitlab::Llm::AiGateway::Client).to receive(:new).with(
        user,
        service_name: :generate_commit_message,
        tracking_context: tracking_context
      )
      expect(ai_client).to receive(:complete).with(
        url: "#{Gitlab::AiGateway.url}/v1/prompts/generate_commit_message",
        body: { 'inputs' => { diff: merge_request.raw_diffs.to_a.map(&:diff).join("\n").truncate_words(10000) } }
      ).and_return(ai_response)

      expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original

      expect(generate_commit_message[:ai_message].content).to eq("Success")
    end
  end
end
