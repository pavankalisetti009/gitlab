# frozen_string_literal: true

require 'grpc'
require 'gitlab/duo_workflow_service'

module Ai
  module DuoWorkflow
    module DuoWorkflowService
      class Client
        def initialize(duo_workflow_service_url:, current_user:)
          @duo_workflow_service_url = duo_workflow_service_url
          @current_user = current_user
        end

        def generate_token
          # TODO: use secure channel for non-localhost URLs

          stub = ::DuoWorkflowService::DuoWorkflow::Stub.new(
            duo_workflow_service_url,
            :this_channel_is_insecure
          )

          request = ::DuoWorkflowService::GenerateTokenRequest.new

          begin
            response = stub.generate_token(request, metadata: metadata)
          rescue StandardError => e
            return ServiceResponse.error(message: e.message)
          end

          ServiceResponse.success(
            message: "JWT Generated",
            payload: { token: response.token, expires_at: response.expiresAt }
          )
        end

        private

        attr_reader :duo_workflow_service_url, :current_user

        def metadata
          {
            "authorization" => "Bearer #{token}",
            "x-gitlab-authentication-type" => "oidc",
            'x-gitlab-instance-id' => ::Gitlab::GlobalAnonymousId.instance_id,
            'x-gitlab-realm' => ::Gitlab::CloudConnector.gitlab_realm,
            'x-gitlab-global-user-id' => ::Gitlab::GlobalAnonymousId.user_id(current_user)
          }
        end

        def token
          ::Gitlab::CloudConnector::SelfIssuedToken.new(
            audience: "gitlab-duo-workflow-service",
            subject: ::Gitlab::CurrentSettings.uuid,
            scopes: ["duo_workflow_generate_token"]
          ).encoded
        end
      end
    end
  end
end
