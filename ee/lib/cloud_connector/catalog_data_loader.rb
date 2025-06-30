# frozen_string_literal: true

module CloudConnector
  class CatalogDataLoader < Gitlab::CloudConnector::DataModel::AbstractDataLoader
    class << self
      def data_loader_class
        @data_loader_class ||= if use_yaml_data_loader?
                                 ::Gitlab::CloudConnector::DataModel::YamlDataLoader
                               else
                                 ::CloudConnector::DatabaseDataLoader
                               end
      end

      private

      def use_yaml_data_loader?
        return true if ::Gitlab::Saas.feature_available?(:cloud_connector_static_catalog)
        return true if License.current.nil? || License.current.offline_cloud_license?

        # This is a temporary fix for self_hosted_models issue:
        # https://gitlab.com/gitlab-org/gitlab/-/issues/552318
        # CloudConnector::AvailableServicesGenerator should always
        # use YamlDataLoader, otherwise it would return empty hash.
        # This can be removed once we have a better way to handle self_hosted_models.
        return true if ::Ai::Setting.self_hosted?

        Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
      end
    end
    def initialize(model_class)
      super

      @loader = self.class.data_loader_class.new(model_class)
    end

    def load!
      loader.load!
    end

    private

    attr_reader :loader
  end
end
