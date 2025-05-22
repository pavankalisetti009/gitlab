# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::DataLoaderFactory, feature_category: :cloud_connector do
  describe '.create_loader' do
    let(:model_class) { Gitlab::CloudConnector::DataModel::UnitPrimitive }

    shared_examples 'returns YamlDataLoader' do
      it 'returns a YamlDataLoader instance' do
        loader = described_class.create_loader(model_class)

        expect(loader).to be_a(Gitlab::CloudConnector::DataModel::YamlDataLoader)
      end
    end

    shared_examples 'returns DatabaseDataLoader' do
      it 'returns a DatabaseDataLoader instance' do
        loader = described_class.create_loader(model_class)

        expect(loader).to be_a(CloudConnector::DatabaseDataLoader)
      end
    end

    context 'when YAML loader should be used via SaaS feature' do
      before do
        stub_saas_features(cloud_connector_static_catalog: true)
      end

      include_examples 'returns YamlDataLoader'
    end

    context 'when YAML loader should be used via offline license' do
      before do
        create_current_license(cloud_licensing_enabled: true, offline_cloud_licensing_enabled: true)
      end

      include_examples 'returns YamlDataLoader'
    end

    context 'when YAML loader should be used via ENV var' do
      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', '1')
      end

      include_examples 'returns YamlDataLoader'
    end

    context 'when none of the conditions are met' do
      before do
        stub_saas_features(cloud_connector_static_catalog: false)
        create_current_license(cloud_licensing_enabled: false, offline_cloud_licensing_enabled: false)
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', 'false')
      end

      include_examples 'returns DatabaseDataLoader'
    end
  end
end
