# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class McpConfigService
      GITLAB_PREAPPROVED_TOOLS = %w[gitlab_search search].freeze
      GITLAB_TOOLS_REQUIRING_APPROVAL = ['semantic_code_search'].freeze
      GITLAB_ENABLED_TOOLS = (GITLAB_PREAPPROVED_TOOLS + GITLAB_TOOLS_REQUIRING_APPROVAL).freeze

      # Workflow definition for agentic chat, which should receive MCP tools.
      # Foundational agents (e.g., "software_development", "analytics_agent/v1")
      # have their own toolsets and should not receive injected MCP tools.
      # See: https://gitlab.com/gitlab-org/gitlab/-/issues/583935
      AGENTIC_CHAT_DEFINITION = 'chat'

      def initialize(current_user, gitlab_token, workflow_definition: nil)
        @current_user = current_user
        @gitlab_token = gitlab_token
        @workflow_definition = workflow_definition
      end

      # This method returns configuration for supported MCP servers
      #
      # Expected configuration format is:
      #
      # {
      #   server_name: {
      #     URL: <server-url>,
      #     Headers: <headers-send-on-each-request>,
      #     Tools: <list-of-supported-tools>, # empty means that all tools will be listed
      #     PreApprovedTools: <list-of-preapproved-tools> # tools that don't require user approval
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
        return unless agentic_chat?

        {
          gitlab: gitlab_mcp_server
        }
      end

      def gitlab_enabled_tools
        return [] unless Feature.enabled?(:mcp_client, current_user)
        return [] unless agentic_chat?

        GITLAB_ENABLED_TOOLS
      end

      private

      attr_reader :gitlab_token, :current_user, :workflow_definition

      def agentic_chat?
        workflow_definition == AGENTIC_CHAT_DEFINITION
      end

      def gitlab_mcp_server
        {
          Headers: {
            Authorization: "Bearer #{gitlab_token}"
          },
          Tools: GITLAB_ENABLED_TOOLS,
          PreApprovedTools: GITLAB_PREAPPROVED_TOOLS
        }
      end
    end
  end
end
