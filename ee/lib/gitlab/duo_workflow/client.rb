# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Client
      def self.url
        return "" unless cloud_connector_url

        cloud_connector_uri = URI.parse(cloud_connector_url)

        "#{cloud_connector_uri.host}:#{cloud_connector_uri.port}"
      end

      def self.headers(user:)
        Gitlab::CloudConnector.headers(user)
      end

      def self.cloud_connector_url
        Gitlab.config.cloud_connector.base_url
      rescue GitlabSettings::MissingSetting
        Gitlab::AppLogger.error('Cloud Connector URL is not present in config/gitlab.yml')

        nil
      end
    end
  end
end
