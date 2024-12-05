# frozen_string_literal: true

module EE
  module Sidebars
    module Admin
      module Panel
        include ::GitlabSubscriptions::CodeSuggestionsHelper
        extend ::Gitlab::Utils::Override

        override :configure_menus
        def configure_menus
          super

          insert_menu_before(
            ::Sidebars::Admin::Menus::DeployKeysMenu,
            ::Sidebars::Admin::Menus::PushRulesMenu.new(context)
          )

          insert_menu_before(
            ::Sidebars::Admin::Menus::DeployKeysMenu,
            ::Sidebars::Admin::Menus::GeoMenu.new(context)
          )

          insert_menu_before(
            ::Sidebars::Admin::Menus::LabelsMenu,
            ::Sidebars::Admin::Menus::CredentialsMenu.new(context)
          )

          insert_menu_after(
            ::Sidebars::Admin::Menus::AbuseReportsMenu,
            ::Sidebars::Admin::Menus::SubscriptionMenu.new(context)
          )

          insert_gilab_duo_menu
        end

        private

        def insert_gilab_duo_menu
          return unless !gitlab_com_subscription? && License.current&.paid?

          insert_menu_after(
            ::Sidebars::Admin::Menus::SubscriptionMenu,
            ::Sidebars::Admin::Menus::CodeSuggestionsMenu.new(context)
          )

          return unless self_hosted_models_enabled?

          insert_menu_after(
            ::Sidebars::Admin::Menus::CodeSuggestionsMenu,
            ::Sidebars::Admin::Menus::SelfHostedModelsMenu.new(context)
          )
        end

        def self_hosted_models_enabled?
          ::Feature.enabled?(:ai_custom_model) && # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
            License.current&.ultimate? &&
            GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.active.exists?
        end
      end
    end
  end
end
