# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class DuoAgentPlatformProbe < BaseProbe
        extend ::Gitlab::Utils::Override

        validate :verify_request_success

        def initialize(user)
          @user = user
          @host = determine_host
        end

        private

        def determine_host
          Gitlab::DuoWorkflow::Client.self_hosted_url.presence ||
            Gitlab::DuoWorkflow::Client.cloud_connected_url(user: @user)
        end

        def result
          ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
            duo_workflow_service_url: @host,
            current_user: @user,
            secure: Gitlab::DuoWorkflow::Client.secure?
          ).list_tools
        end

        def verify_request_success
          return if result[:status] == :success

          errors.add(:base, result[:message])
        end

        override :success_message
        def success_message
          format(_('GitLab Duo Workflow Service at %{host} is operational.'), host: @host)
        end

        def failure_message
          format(_('GitLab Duo Workflow Service at %{host} is not operational.'), host: @host)
        end
      end
    end
  end
end
