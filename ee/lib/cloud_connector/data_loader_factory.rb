# frozen_string_literal: true

module CloudConnector
  class DataLoaderFactory
    def self.create_loader(model_class)
      if use_yaml_data_loader?
        Gitlab::CloudConnector::DataModel::YamlDataLoader.new(model_class)
      else
        ::CloudConnector::DatabaseDataLoader.new(model_class)
      end
    end

    def self.use_yaml_data_loader?
      return true if ::Gitlab::Saas.feature_available?(:cloud_connector_static_catalog)
      return true if License.current&.offline_cloud_license?

      Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
    end
  end
end
