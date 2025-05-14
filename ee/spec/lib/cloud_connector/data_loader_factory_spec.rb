# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::DataLoaderFactory, feature_category: :cloud_connector do
  describe '.create_loader' do
    let(:model_class) { Gitlab::CloudConnector::DataModel::UnitPrimitive }

    context 'when YAML loader should be used' do
      before do
        stub_saas_features(cloud_connector_static_catalog: true)
      end

      it 'returns a YamlDataLoader instance' do
        loader = described_class.create_loader(model_class)

        expect(loader).to be_a(Gitlab::CloudConnector::DataModel::YamlDataLoader)
      end
    end

    context 'when database loader should be used' do
      before do
        stub_saas_features(cloud_connector_static_catalog: false)
      end

      it 'returns a DatabaseDataLoader instance' do
        loader = described_class.create_loader(model_class)

        expect(loader).to be_a(CloudConnector::DatabaseDataLoader)
      end
    end
  end

  describe '.use_yaml_data_loader?' do
    context 'when on gitlab.com', :saas do
      before do
        stub_saas_features(cloud_connector_static_catalog: true)
      end

      it 'returns true' do
        expect(described_class.use_yaml_data_loader?).to be true
      end
    end

    context 'when License is an offline cloud license' do
      before do
        create_current_license(cloud_licensing_enabled: true, offline_cloud_licensing_enabled: true)
      end

      it 'returns true' do
        expect(described_class.use_yaml_data_loader?).to be true
      end
    end

    context 'when CLOUD_CONNECTOR_SELF_SIGN_TOKENS environment variable is set' do
      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', '1')
      end

      it 'returns true' do
        expect(described_class.use_yaml_data_loader?).to be true
      end
    end

    context 'when none of the conditions are met' do
      before do
        stub_saas_features(cloud_connector_static_catalog: false)
        create_current_license(cloud_licensing_enabled: false, offline_cloud_licensing_enabled: false)
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', 'false')
      end

      it 'returns false' do
        expect(described_class.use_yaml_data_loader?).to be false
      end
    end
  end
end
