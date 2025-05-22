# frozen_string_literal: true

module CloudConnector
  class CatalogDataLoader < Gitlab::CloudConnector::DataModel::AbstractDataLoader
    def initialize(model_class)
      super

      @loader = ::CloudConnector::DataLoaderFactory.create_loader(model_class)
    end

    def load!
      loader.load!
    end

    private

    attr_reader :loader
  end
end
