# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::Client, feature_category: :duo_workflow do
  let(:user) { create(:user) }
  let(:cloud_connector_url) { 'https://duo-workflow-service.example.com' }

  before do
    allow(Gitlab.config.cloud_connector).to receive(:base_url).and_return cloud_connector_url
  end

  describe '.url' do
    it 'returns correct url' do
      expect(described_class.url).to eq("duo-workflow-service.example.com:443")
    end
  end

  describe '.headers' do
    it 'returns correct headers' do
      expect(Gitlab::CloudConnector).to receive(:headers).with(user).and_return({ header_key: 'header_value' })

      expect(described_class.headers(user: user)).to eq({ header_key: 'header_value' })
    end
  end

  describe '.cloud_connector_url' do
    context 'when cloud_connector is configured' do
      it 'returns cloud connector base url' do
        expect(described_class.cloud_connector_url).to eq(cloud_connector_url)
      end
    end

    context 'when cloud_connector is not configured' do
      before do
        allow(Gitlab.config).to receive(:cloud_connector).and_raise(GitlabSettings::MissingSetting)
      end

      it 'returns nil' do
        expect(described_class.cloud_connector_url).to be_nil
      end
    end
  end

  describe '.secure?' do
    context 'when cloud_connector is configured to https' do
      it 'returns true' do
        expect(described_class.secure?).to eq(true)
      end
    end

    context 'when cloud_connector is configured to http' do
      before do
        allow(Gitlab.config.cloud_connector).to receive(:base_url).and_return 'http://duo-workflow-service.example.com'
      end

      it 'returns false' do
        expect(described_class.secure?).to eq(false)
      end
    end

    context 'when cloud_connector is not configured' do
      before do
        allow(Gitlab.config).to receive(:cloud_connector).and_raise(GitlabSettings::MissingSetting)
      end

      it 'returns nil' do
        expect(described_class.secure?).to eq(false)
      end
    end
  end
end
