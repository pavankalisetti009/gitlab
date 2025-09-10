# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class DuoAgentPlatformModelMetadataService
      FEATURE_NAME = :duo_agent_platform

      def initialize(root_namespace: nil)
        @root_namespace = root_namespace
      end

      def execute
        return resolve_self_managed_model_metadata if self_managed?

        resolve_gitlab_com_model_metadata
      end

      private

      attr_reader :root_namespace

      def self_managed?
        !::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end

      def duo_agent_platform_in_self_hosted_duo?
        ::Ai::FeatureSetting.duo_agent_platform.self_hosted.exists?
      end

      def resolve_self_managed_model_metadata
        if duo_agent_platform_in_self_hosted_duo?
          resolve_self_hosted_duo_model_metadata
        else
          resolve_cloud_connected_model_metadata
        end
      end

      # Self-Hosted Duo Priority:
      # 1. Self-hosted feature setting (admin-configured models only)
      # Note: No user model selection - limited to what admin sets up
      def resolve_self_hosted_duo_model_metadata
        return {} unless Feature.enabled?(:self_hosted_agent_platform, :instance)

        feature_setting = ::Ai::FeatureSetting.find_by_feature(FEATURE_NAME)

        ::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata.new(
          feature_setting: feature_setting
        ).execute
      end

      # Cloud-Connected Self-Managed Priority (same user empowerment as GitLab.com):
      # 1. Instance-level model selection (admin sets instance defaults)
      # 2. User model selection (users can override instance defaults)
      def resolve_cloud_connected_model_metadata
        return {} unless Feature.enabled?(:instance_level_model_selection, :instance)

        # Priority 1: Instance-level model selection
        instance_setting = ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting
                            .find_or_initialize_by_feature(FEATURE_NAME)

        ::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata.new(
          feature_setting: instance_setting
        ).execute

        # Priority 2: User model selection - handled at API level
        # TODO: Implement when frontend integration is ready
        # Same as GitLab.com - user can override instance defaults
      end

      # GitLab.com Priority:
      # 1. Namespace-level model selection (organization/group defaults)
      # 2. User model selection (users can override namespace defaults)
      def resolve_gitlab_com_model_metadata
        return {} unless root_namespace

        return {} unless Feature.enabled?(:duo_agent_platform_model_selection, root_namespace)
        # Priority 1: Namespace-level model selection
        return {} unless Feature.enabled?(:ai_model_switching, root_namespace)

        namespace_setting = ::Ai::ModelSelection::NamespaceFeatureSetting
                             .find_or_initialize_by_feature(root_namespace, FEATURE_NAME)

        ::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata.new(
          feature_setting: namespace_setting
        ).execute

        # Priority 2: User model selection - handled at API level
        # TODO: Implement when frontend integration is ready
      end
    end
  end
end
