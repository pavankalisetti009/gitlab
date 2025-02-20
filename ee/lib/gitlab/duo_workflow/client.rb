# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Client
      def self.url
        Gitlab.config.duo_workflow.service_url
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
