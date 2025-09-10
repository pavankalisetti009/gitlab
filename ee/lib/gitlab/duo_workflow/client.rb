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
            'x-gitlab-base-url' => Gitlab.config.gitlab.url,
            'authorization' => "Bearer #{cloud_connector_token(user: user)}",
            'x-gitlab-authentication-type' => 'oidc'
          )

        headers.delete('x-gitlab-base-url') if Feature.enabled?(:duo_agent_platform_disable_direct_http, user)

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
          extended_logging: enable_extended_logging?(user),
          is_team_member:
            ::Gitlab::Tracking::StandardContext.new.gitlab_team_member?(user&.id)
        }
      end

      private_class_method def self.enable_extended_logging?(user)
        # For a self-hosted Duo instance, return the value of the
        # instance setting.
        return ::Ai::Setting.instance&.enabled_instance_verbose_ai_logs if self_hosted_url

        Feature.enabled?(:duo_workflow_extended_logging, user)
      end
    end
  end
end
