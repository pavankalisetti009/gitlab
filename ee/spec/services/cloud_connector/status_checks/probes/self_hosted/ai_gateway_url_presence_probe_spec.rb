# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe, feature_category: :cloud_connector do
  let(:probe) { described_class.new }

  describe '#execute' do
    context 'when AI_GATEWAY_URL is set' do
      before do
        stub_env('AI_GATEWAY_URL', 'https://ai-gateway.mycompany.com')
      end

      it 'returns a successful result' do
        result = probe.execute
        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be(true)
        expect(result.message).to eq('Environment variable AI_GATEWAY_URL is set to https://ai-gateway.mycompany.com.')
      end
    end

    context 'when AI_GATEWAY_URL is not set' do
      before do
        stub_env('AI_GATEWAY_URL', nil)
      end

      it 'returns a failed result' do
        result = probe.execute
        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be(false)
        expect(result.message).to eq('Environment variable AI_GATEWAY_URL is not set.')
      end
    end
  end
end
