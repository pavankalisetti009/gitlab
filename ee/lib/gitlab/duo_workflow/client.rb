# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Client
      def self.url
        Gitlab.config.duo_workflow.service_url
      end

      def self.headers(user:)
        Gitlab::CloudConnector.ai_headers(user)
      end

      def self.secure?
        !!Gitlab.config.duo_workflow.secure
      end
    end
  end
end
