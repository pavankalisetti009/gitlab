# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Client
      def self.url
        ENV['DUO_WORKFLOW_SERVICE_URL']
      end

      def self.headers(user:)
        Gitlab::CloudConnector.headers(user)
      end
    end
  end
end
