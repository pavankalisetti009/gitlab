# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::Client, feature_category: :duo_workflow do
  let(:user) { create(:user) }
  let(:workflow_service_url) { 'https://duo-workflow-service.example.com' }

  before do
    stub_env('DUO_WORKFLOW_SERVICE_URL', workflow_service_url)
  end

  describe '.url' do
    it 'returns correct url' do
      expect(described_class.url).to eq(workflow_service_url)
    end
  end

  describe '.headers' do
    it 'returns correct headers' do
      expect(Gitlab::CloudConnector).to receive(:headers).with(user).and_return({ header_key: 'header_value' })

      expect(described_class.headers(user: user)).to eq({ header_key: 'header_value' })
    end
  end
end
