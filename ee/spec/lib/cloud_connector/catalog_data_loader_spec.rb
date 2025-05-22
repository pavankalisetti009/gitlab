# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::CatalogDataLoader, feature_category: :cloud_connector do
  let(:model_class) { Gitlab::CloudConnector::DataModel::UnitPrimitive }
  let(:selected_loader) { instance_double(CloudConnector::DatabaseDataLoader) }

  subject(:catalog_loader) { described_class.new(model_class) }

  before do
    allow(CloudConnector::DataLoaderFactory).to receive(:create_loader).with(model_class).and_return(selected_loader)
  end

  describe '#load!' do
    it 'delegates to the loader provided by the factory' do
      expected_result = [instance_double(model_class)]

      expect(selected_loader).to receive(:load!).and_return(expected_result)

      result = catalog_loader.load!

      expect(result).to eq(expected_result)
    end
  end
end
