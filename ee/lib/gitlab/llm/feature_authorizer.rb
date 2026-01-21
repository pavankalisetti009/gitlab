# frozen_string_literal: true

module Gitlab
  module Llm
    class FeatureAuthorizer
      def self.can_access_duo_external_trigger?(user:, container:)
        return false unless container.duo_features_enabled

        user.assigned_to_duo_add_ons?(container) ||
          user.assigned_to_duo_core?(container) ||
          has_duo_core_via_namespace_settings?(user, container) ||
          GitlabSubscriptions::AddOnPurchase.for_self_managed.for_duo_core.active.exists?
      end

      def self.has_duo_core_via_namespace_settings?(user, container)
        return false unless container.respond_to?(:root_ancestor)

        user.duo_core_ids_via_namespace_settings.include?(container.root_ancestor.id)
      end
      private_class_method :has_duo_core_via_namespace_settings?

      def initialize(container:, feature_name:, user:, licensed_feature: :ai_features)
        @container = container
        @feature_name = feature_name
        @user = user
        @licensed_feature = licensed_feature
      end

      def allowed?
        return false unless user
        return false unless container
        return false unless Gitlab::Llm::Utils::FlagChecker.flag_enabled_for_feature?(feature_name)

        return false unless user.allowed_to_use?(
          feature_name,
          licensed_feature: licensed_feature,
          root_namespace: container.root_ancestor
        )

        return false unless container.duo_features_enabled

        ::Gitlab::Llm::StageCheck.available?(container, feature_name)
      end

      private

      attr_reader :container, :feature_name, :user, :licensed_feature
    end
  end
end
