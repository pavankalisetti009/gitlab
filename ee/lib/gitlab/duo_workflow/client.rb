# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Client
      def self.url(user:)
        self_hosted_url || cloud_connected_url(user: user)
      end

      def self.cloud_connected_url(user:)
        Gitlab.config.duo_workflow.service_url || default_service_url(user: user)
      end

      def self.default_service_url(user:)
        if Feature.enabled?(:duo_workflow_cloud_connector_url, user)
          return "#{::CloudConnector::Config.host}:#{::CloudConnector::Config.port}"
        end

        subdomain = ::CloudConnector::Config.host.include?('staging') ? '.staging' : ''

        # Cloudflare has been disabled untill
        # gets resolved https://gitlab.com/gitlab-org/gitlab/-/issues/509586
        # "#{::CloudConnector::Config.host}:#{::CloudConnector::Config.port}"
        "duo-workflow-svc#{subdomain}.runway.gitlab.net:#{::CloudConnector::Config.port}"
      end

      def self.url_for(feature_setting:, user:)
        if feature_setting&.self_hosted?
          self_hosted_url
        else
          cloud_connected_url(user: user)
        end
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

      def self.cloud_connector_headers(user:, feature_setting: nil)
        headers = Gitlab::AiGateway
          .public_headers(user: user, ai_feature_name: :duo_workflow,
            unit_primitive_name: :duo_workflow_execute_workflow,
            feature_setting: feature_setting)
          .transform_keys(&:downcase)
          .merge(
            'authorization' => "Bearer #{cloud_connector_token(user: user, feature_setting: feature_setting)}",
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

      def self.cloud_connector_token(user:, feature_setting: nil)
        ::CloudConnector::Tokens.get(
          unit_primitive: :duo_agent_platform,
          resource: user,
          feature_setting: feature_setting
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
