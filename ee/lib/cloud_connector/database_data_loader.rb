# frozen_string_literal: true

module CloudConnector
  class DatabaseDataLoader < Gitlab::CloudConnector::DataModel::AbstractDataLoader
    include ::CloudConnector::Utils

    DATE_FIELDS = %w[cut_off_date].freeze
    CATALOG_STORE_KEY = 'cloud_connector:catalog_json'

    def load!
      Gitlab::SafeRequestStore.fetch(cache_key) do
        if catalog_data.empty?
          log_warning("Catalog is empty or not synced")

          next []
        end

        data = catalog_data[model_name]

        if data.blank?
          log_warning("Catalog key '#{model_name}' is missing or empty")

          next []
        end

        data.map { |raw_data| model_class.new(**transform_attributes(raw_data)) }
      end
    end

    private

    def transform_attributes(data)
      attributes = data.dup

      DATE_FIELDS.each do |field|
        attributes[field] = parse_time(attributes[field]) if attributes.key?(field)
      end

      attributes
    end

    def catalog_data
      Gitlab::SafeRequestStore.fetch(CATALOG_STORE_KEY) do
        CloudConnector::Access.with_catalog.last&.catalog || {}
      end
    end

    def model_name
      @model_name ||= model_class.model_name.tableize
    end

    def cache_key
      "#{self.class.name.underscore.tr('/', ':')}:#{model_name}"
    end

    def log_warning(message)
      ::Gitlab::AppLogger.warn(message: message, class_name: self.class.name)
    end
  end
end
