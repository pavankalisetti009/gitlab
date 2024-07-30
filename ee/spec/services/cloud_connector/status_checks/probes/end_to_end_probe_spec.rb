# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::EndToEndProbe, feature_category: :cloud_connector do
  let(:probe) { described_class.new }
  let(:user) { build(:user) }

  describe '#execute' do
    context 'when code completion test is successful' do
      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
          allow(client).to receive(:test_completion).and_return(nil)
        end
      end

      it 'returns a success result' do
        result = probe.execute(user: user)

        expect(result.success).to be true
        expect(result.message).to eq('Code completion test was successful')
      end
    end

    context 'when code completion test fails' do
      let(:error_message) { 'API error' }

      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
          allow(client).to receive(:test_completion).and_return(error_message)
        end
      end

      it 'returns a failure result with the error message' do
        result = probe.execute(user: user)

        expect(result.success).to be false
        expect(result.message).to eq("Code completion test failed: #{error_message}")
      end
    end
  end
end
