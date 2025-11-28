# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe, feature_category: :duo_setting do
  let(:user) { build(:user) }
  let(:probe) { described_class.new(user) }
  let(:duo_workflow_client) { instance_double(Ai::DuoWorkflow::DuoWorkflowService::Client) }

  before do
    allow(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).and_return(duo_workflow_client)
    allow(Gitlab::DuoWorkflow::Client).to receive(:secure?).and_return(true)
  end

  shared_examples 'successful probe execution' do
    let(:success_response) { { status: :success, message: 'Tools listed successfully', payload: { tools: [] } } }

    before do
      allow(duo_workflow_client).to receive(:list_tools).and_return(success_response)
    end

    it 'returns a successful result' do
      result = probe.execute

      expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
      expect(result.success?).to be(true)
      expect(result.message).to eq("GitLab Duo Workflow Service at #{host} is operational.")
    end

    it 'calls DuoWorkflowService::Client with correct parameters' do
      probe.execute

      expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to have_received(:new).with(
        duo_workflow_service_url: host,
        current_user: user,
        secure: true
      )
      expect(duo_workflow_client).to have_received(:list_tools)
    end
  end

  shared_examples 'failed probe execution' do
    let(:error_response) { { status: :error, message: 'Connection failed' } }

    before do
      allow(duo_workflow_client).to receive(:list_tools).and_return(error_response)
    end

    it 'returns a failed result' do
      result = probe.execute

      expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
      expect(result.success?).to be(false)
      expect(result.message).to eq("GitLab Duo Workflow Service at #{host} is not operational.")
    end
  end

  describe '#execute' do
    context 'when using cloud-connected URL' do
      let(:host) { 'duo-workflow-svc.runway.gitlab.net:443' }

      before do
        allow(Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
        allow(Gitlab::DuoWorkflow::Client).to receive(:cloud_connected_url).with(user: user).and_return(host)
      end

      context 'when list_tools succeeds' do
        include_examples 'successful probe execution'
      end

      context 'when list_tools fails' do
        include_examples 'failed probe execution'
      end

      context 'with staging environment' do
        let(:staging_host) { 'duo-workflow-svc.staging.runway.gitlab.net:443' }

        before do
          allow(Gitlab::DuoWorkflow::Client).to receive(:cloud_connected_url).with(user: user).and_return(staging_host)
          allow(duo_workflow_client).to receive(:list_tools).and_return({ status: :success })
        end

        it 'uses the staging URL' do
          probe.execute

          expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to have_received(:new).with(
            duo_workflow_service_url: staging_host,
            current_user: user,
            secure: true
          )
        end
      end
    end

    context 'when using self-hosted URL' do
      let(:host) { 'localhost:50052' }

      before do
        allow(Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(host)
      end

      context 'when list_tools succeeds' do
        include_examples 'successful probe execution'
      end

      context 'when list_tools fails' do
        include_examples 'failed probe execution'
      end
    end
  end
end
