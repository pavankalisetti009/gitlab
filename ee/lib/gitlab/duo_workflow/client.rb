# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Client
      def self.url
        self_hosted_url ||
          Gitlab.config.duo_workflow.service_url ||
          default_service_url
      end

      def self.default_service_url
        "#{::CloudConnector::Config.host}:#{::CloudConnector::Config.port}"
      end

      def self.self_hosted_url
        ::Ai::Setting.instance&.duo_agent_platform_service_url.presence
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

      def self.cloud_connector_headers(user:)
        headers = Gitlab::AiGateway
          .public_headers(user: user, ai_feature_name: :duo_workflow,
            unit_primitive_name: :duo_workflow_execute_workflow)
          .transform_keys(&:downcase)
          .merge(
            'authorization' => "Bearer #{cloud_connector_token(user: user)}",
            'x-gitlab-authentication-type' => 'oidc'
          )

        # The feature flag should stay disabled globally and by default. We inverted the value in this MR:
        #
        # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/204647
        #
        # To be able to identify whether some particular problem happens due to direct-http disablement.
        # Once we issues are resolved, this line can be removed along with the disabled feature flag.
        headers['x-gitlab-base-url'] = Gitlab.config.gitlab.url if Feature.enabled?(
          :duo_agent_platform_enable_direct_http, user)

        headers
      end

      def self.cloud_connector_token(user:)
        ::CloudConnector::Tokens.get(
          unit_primitive: :duo_agent_platform,
          resource: user
        )
      end

      def self.metadata(user)
        {
          extended_logging: Feature.enabled?(:duo_workflow_extended_logging, user),
          is_team_member:
            ::Gitlab::Tracking::StandardContext.new.gitlab_team_member?(user&.id)
        }
      end
    end
  end
end
