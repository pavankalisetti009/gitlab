# frozen_string_literal: true

module Ai
  module Catalog
    class << self
      def available?(user)
        feature_available?(user) && # rubocop:disable Gitlab/FeatureAvailableUsage -- Not a license check
          user_can_access_experimental_ai_catalog_features?(user)
      end

      private

      def feature_available?(user)
        return false unless ::Feature.enabled?(:global_ai_catalog, user)

        saas? || ::Gitlab::CurrentSettings.duo_features_enabled?
      end

      # TODO remove this when AI Catalog goes GA
      # https://gitlab.com/gitlab-org/gitlab/-/issues/570161
      def user_can_access_experimental_ai_catalog_features?(user)
        return true if Gitlab::Llm::Utils::AiFeaturesCatalogue.instance_should_observe_ga_dap?(:ai_catalog, user: user)

        # SaaS, check if the user belongs to any (root) namespace with `experiment_features_enabled`
        if saas?
          return user.present? &&
              user.authorized_groups.top_level.namespace_settings_with_ai_features_enabled.any?
        end

        # Self-managed/Dedicated
        true
      end

      def saas?
        ::Gitlab::Saas.feature_available?(:ai_catalog)
      end
    end
  end
end
