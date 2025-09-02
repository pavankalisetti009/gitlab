# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::SelfHosted::DuoAgentPlatformProbe, feature_category: :"self-hosted_models" do
  let(:user) { build(:user) }
  let(:host) { 'localhost:50052' }
  let(:probe) { described_class.new(user) }
  let(:duo_workflow_client) { instance_double(Ai::DuoWorkflow::DuoWorkflowService::Client) }

  before do
    allow(Gitlab::DuoWorkflow::Client).to receive_messages(self_hosted_url: host, secure?: true)
  end

  describe '#execute' do
    before do
      allow(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).and_return(duo_workflow_client)
    end

    context 'when generate_token succeeds' do
      let(:success_response) { { status: :success, message: 'JWT Generated', payload: { token: 'test-token' } } }

      before do
        allow(duo_workflow_client).to receive(:generate_token).and_return(success_response)
      end

      it 'returns a successful result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be(true)
        expect(result.message).to eq("#{host} reachable.")
      end

      it 'calls DuoWorkflowService::Client with correct parameters' do
        probe.execute

        expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to have_received(:new).with(
          duo_workflow_service_url: host,
          current_user: user,
          secure: true
        )
        expect(duo_workflow_client).to have_received(:generate_token)
      end
    end

    context 'when generate_token fails' do
      let(:error_response) { { status: :error, message: 'Connection failed' } }

      before do
        allow(duo_workflow_client).to receive(:generate_token).and_return(error_response)
      end

      it 'returns a failed result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be(false)
        expect(result.message).to eq("Duo Agent Platform Service URL #{host} is not reachable..")
      end
    end
  end
end
