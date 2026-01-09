# frozen_string_literal: true

module Ai
  module Catalog
    CACHE_EXPIRATION = 30.minutes
    private_constant :CACHE_EXPIRATION

    class << self
      def available?(user)
        feature_available?(user) && # rubocop:disable Gitlab/FeatureAvailableUsage -- Not a license check
          duo_agent_platform_available_for_user?(user) &&
          user_can_access_experimental_ai_catalog_features?(user) &&
          user.allowed_to_use_through_namespace?(:ai_catalog)
      end

      private

      def duo_agent_platform_available_for_user?(user)
        return false unless user

        if saas?
          # On SaaS, check if user belongs to any top-level group with:
          # 1. Premium or Ultimate license (ai_catalog is available in Premium+)
          # 2. duo_agent_platform_enabled in ai_settings
          cached_duo_agent_platform_available?(user)
        else
          # On self-managed/dedicated, check instance-level setting
          ::Ai::Setting.instance.duo_agent_platform_enabled
        end
      end

      def cached_duo_agent_platform_available?(user)
        # Skip cache in development for instant feedback
        return duo_agent_platform_enabled_for_user?(user) unless Rails.env.production?

        cache_key = "ai_catalog:duo_agent_platform_available:#{user.id}"
        Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRATION) do
          duo_agent_platform_enabled_for_user?(user)
        end
      end

      def duo_agent_platform_enabled_for_user?(user)
        user.authorized_groups.top_level.with_ai_supported_plan(:ai_catalog).any?(&:duo_agent_platform_enabled)
      end

      def feature_available?(user)
        return false unless ::Feature.enabled?(:global_ai_catalog, user)

        saas? || ::Gitlab::CurrentSettings.duo_features_enabled?
      end

      # TODO remove this when AI Catalog goes GA
      # https://gitlab.com/gitlab-org/gitlab/-/issues/570161
      def user_can_access_experimental_ai_catalog_features?(user)
        return true if Gitlab::Llm::Utils::AiFeaturesCatalogue.instance_should_observe_ga_dap?(:ai_catalog)

        # SaaS, check if the user belongs to any (root) namespace with `experiment_features_enabled`
        if saas?
          return user.present? &&
              user.authorized_groups.top_level.namespace_settings_with_ai_features_enabled.any?
        end

        # Self-managed/Dedicated, check the instance level setting
        ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
      end

      def saas?
        ::Gitlab::Saas.feature_available?(:ai_catalog)
      end
    end
  end
end
