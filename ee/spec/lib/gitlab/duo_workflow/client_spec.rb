# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::Client, feature_category: :duo_workflow do
  let(:user) { create(:user) }

  describe '.url' do
    it 'returns url to Duo Workflow Service fleet' do
      expect(described_class.url).to eq('duo-workflow-svc.runway.gitlab.net:443')
    end

    context 'when new_duo_workflow_service feature flag is disabled' do
      before do
        stub_feature_flags(new_duo_workflow_service: false)
      end

      it 'returns url to legacy Duo Workflow Service fleet' do
        expect(described_class.url).to eq('duo-workflow.runway.gitlab.net:443')
      end
    end

    context 'when cloud connector url is staging' do
      before do
        allow(::CloudConnector::Config).to receive(:host).and_return('cloud.staging.gitlab.com')
      end

      it 'returns url to staging Duo Workflow Service fleet' do
        expect(described_class.url).to eq('duo-workflow-svc.staging.runway.gitlab.net:443')
      end
    end

    context 'when url is set in config' do
      let(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }

      before do
        allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
      end

      it 'returns configured url' do
        expect(described_class.url).to eq(duo_workflow_service_url)
      end
    end
  end

  describe '.headers' do
    it 'returns cloud connector headers' do
      expect(::CloudConnector).to receive(:ai_headers).with(user).and_return({ header_key: 'header_value' })

      expect(described_class.headers(user: user)).to eq({ header_key: 'header_value' })
    end
  end

  describe '.secure?' do
    it 'returns secure config' do
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return true
      expect(described_class.secure?).to eq(true)
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return false
      expect(described_class.secure?).to eq(false)
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return nil
      expect(described_class.secure?).to eq(false)
    end
  end
end
