# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class McpConfigService
      GITLAB_ENABLED_TOOLS = ['get_issue'].freeze

      def initialize(current_user, gitlab_token)
        @current_user = current_user
        @gitlab_token = gitlab_token
      end

      # This method returns configuration for supported MCP servers
      #
      # Expected configuration format is:
      #
      # {
      #   server_name: {
      #     URL: <server-url>,
      #     Headers: <headers-send-on-each-request>,
      #     Tools: <list-of-supported-tools> # empty means that all tools will be listed
      #   }
      # }
      #
      # GitLab configuration is hard-coded, while the list may also contain other server configurations
      # For example,
      # {
      #   gitlab: gitlab_mcp_server,
      #   context7: {
      #     URL: "https://mcp.context7.com/mcp",
      #   }
      # }
      #
      # Or the list can be extended by user provided configurations on namespace/project/user levels
      def execute
        return unless Feature.enabled?(:mcp_client, current_user)

        {
          gitlab: gitlab_mcp_server
        }
      end

      def gitlab_enabled_tools
        return [] unless Feature.enabled?(:mcp_client, current_user)

        GITLAB_ENABLED_TOOLS
      end

      private

      attr_reader :gitlab_token, :current_user

      def gitlab_mcp_server
        {
          Headers: {
            Authorization: "Bearer #{gitlab_token}"
          },
          Tools: GITLAB_ENABLED_TOOLS
        }
      end
    end
  end
end
