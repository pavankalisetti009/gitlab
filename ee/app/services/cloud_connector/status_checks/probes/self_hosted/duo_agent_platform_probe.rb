# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      module SelfHosted
        class DuoAgentPlatformProbe < BaseProbe
          extend ::Gitlab::Utils::Override

          validate :verify_request_success

          def initialize(user)
            @user = user
            @host = Gitlab::DuoWorkflow::Client.self_hosted_url
          end

          private

          def result
            ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
              duo_workflow_service_url: @host,
              current_user: @user,
              secure: Gitlab::DuoWorkflow::Client.secure?
            ).generate_token
          end

          def verify_request_success
            return if result[:status] == :success

            errors.add(:base, result[:message])
          end

          override :success_message
          def success_message
            format(_('%{host} reachable.'), host: @host)
          end

          def failure_message
            format(_(
              "Duo Agent Platform Service URL %{host} is not reachable.."
            ), host: @host)
          end
        end
      end
    end
  end
end
