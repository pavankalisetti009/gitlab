# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    # Service responsible for configuring SRT (Secure Runtime) sandbox for Duo Workflow execution
    # This class configures network firewall and filesystem restrictions for DAP ambient sessions.
    class Sandbox
      def initialize(current_user:, duo_workflow_service_url:)
        @current_user = current_user
        @duo_workflow_service_url = duo_workflow_service_url
      end

      # Wraps a command with SRT sandbox if enabled
      # @param command [String] The command to wrap
      # @return [Array<String>] Array with shell commands
      def wrap_command(command)
        return [command] unless enabled?

        [
          %(if which srt > /dev/null; then),
          %(  echo "SRT found, creating config..."),
          %(  echo '#{Gitlab::Json.dump(srt_config)}' > /tmp/srt-settings.json),
          %(  echo "Testing SRT sandbox capabilities..."),
          %(  if srt --settings /tmp/srt-settings.json true 2>/dev/null; then),
          %(    echo "SRT sandbox test successful, running command: #{command}"),
          %(    srt --settings /tmp/srt-settings.json #{command}),
          %(  else),
          %(    echo "Warning: SRT found but can't create sandbox (insufficient privileges), running command directly"),
          %(    echo "For more details visit: https://docs.gitlab.com/user/duo_agent_platform/flows/execution/#configure-runners"),
          %(    #{command}),
          %(  fi),
          %(else),
          %(  echo "Warning: srt is not installed or not in PATH, running command directly without sandbox"),
          %(  echo "For more details visit: https://docs.gitlab.com/user/duo_agent_platform/flows/execution/#configure-runners"),
          %(  #{command}),
          %(fi),
          %(echo "Command execution completed with exit code: $?")
        ]
      end

      # Returns environment variables needed for SRT sandbox
      # @return [Hash] Environment variables
      def environment_variables
        return {} unless enabled?

        {
          NPM_CONFIG_CACHE: "/tmp/.npm-cache",
          GITLAB_LSP_STORAGE_DIR: "/tmp"
        }
      end

      private

      # Checks if network firewall is enabled
      # @return [Boolean]
      def enabled?
        Feature.enabled?(:ai_duo_agent_platform_network_firewall, @current_user) &&
          Feature.enabled?(:ai_dap_executor_connects_over_ws, @current_user)
      end

      # Generates SRT configuration for network and filesystem restrictions
      # @return [Hash] SRT configuration
      def srt_config
        {
          network: {
            allowedDomains: allowlisted_domains,
            deniedDomains: [],
            allowUnixSockets: ["/var/run/docker.sock"],
            allowLocalBinding: true
          },
          filesystem: {
            denyRead: ["~/.ssh"],
            allowWrite: ["./", "/tmp/"],
            denyWrite: []
          }
        }
      end

      # Returns list of domains allowed for network access
      # @return [Array<String>] Allowed domains
      def allowlisted_domains
        [
          "host.docker.internal",
          "localhost",
          extract_domain(Gitlab.config.gitlab.url),
          "*.#{extract_domain(Gitlab.config.gitlab.url)}",
          extract_domain(@duo_workflow_service_url)
        ]
      end

      # Extracts domain from a URL
      # @param url [String] URL to extract domain from
      # @return [String, nil] Extracted domain
      def extract_domain(url)
        return url if url.blank?

        # Try parsing as a full URI first
        uri = URI.parse(url)
        return uri.host if uri.host

        # If no host found, try parsing as just host:port by prepending //
        uri = URI.parse("//#{url}")
        uri.host
      rescue URI::InvalidURIError
        # Fallback: if it contains a colon, assume it's host:port
        url.include?(':') ? url.split(':').first : url
      end
    end
  end
end
