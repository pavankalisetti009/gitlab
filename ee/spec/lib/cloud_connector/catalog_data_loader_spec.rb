# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::CatalogDataLoader, feature_category: :plan_provisioning do
  let(:model_class) { Gitlab::CloudConnector::DataModel::UnitPrimitive }

  subject(:catalog_loader) { described_class.new(model_class) }

  describe '#load!' do
    let(:loader_instance) { instance_double(described_class.data_loader_class) }
    let(:expected_result) { [instance_double(model_class)] }

    before do
      allow(described_class.data_loader_class).to receive(:new).with(model_class).and_return(loader_instance)
      allow(loader_instance).to receive(:load!).and_return(expected_result)
    end

    it 'delegates to the selected loader class' do
      result = catalog_loader.load!
      expect(result).to eq(expected_result)
    end
  end

  describe '.data_loader_class' do
    subject(:loader_class) { described_class.data_loader_class }

    before do
      described_class.instance_variable_set(:@data_loader_class, nil)
    end

    context 'when on gitlab.com', :saas do
      it { is_expected.to eq(Gitlab::CloudConnector::DataModel::YamlDataLoader) }
    end

    context 'when offline license is used' do
      before do
        create_current_license(cloud_licensing_enabled: true, offline_cloud_licensing_enabled: true)
      end

      it { is_expected.to eq(Gitlab::CloudConnector::DataModel::YamlDataLoader) }
    end

    context 'when Duo self-hosted is used' do
      before do
        allow(Ai::Setting).to receive(:self_hosted?).and_return(true)
      end

      it { is_expected.to eq(Gitlab::CloudConnector::DataModel::YamlDataLoader) }
    end

    context 'when ENV var is set to true' do
      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', '1')
      end

      it { is_expected.to eq(Gitlab::CloudConnector::DataModel::YamlDataLoader) }
    end

    context 'when License.current is nil' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it { is_expected.to eq(Gitlab::CloudConnector::DataModel::YamlDataLoader) }
    end
  end
end
