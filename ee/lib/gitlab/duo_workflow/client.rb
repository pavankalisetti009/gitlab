# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Client
      def self.url
        Gitlab.config.duo_workflow.service_url || default_service_url
      end

      def self.default_service_url
        subdomain = ::CloudConnector::Config.host.include?('staging') ? '.staging' : ''

        # Cloudflare has been disabled untill
        # gets resolved https://gitlab.com/gitlab-org/gitlab/-/issues/509586
        # "#{::CloudConnector::Config.host}:#{::CloudConnector::Config.port}"
        "duo-workflow-svc#{subdomain}.runway.gitlab.net:#{::CloudConnector::Config.port}"
      end

      def self.headers(user:)
        ::CloudConnector.ai_headers(user)
      end

      def self.secure?
        !!Gitlab.config.duo_workflow.secure
      end

      def self.debug_mode?
        !!Gitlab.config.duo_workflow.debug
      end
    end
  end
end
