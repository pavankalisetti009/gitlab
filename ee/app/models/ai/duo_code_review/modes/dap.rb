# frozen_string_literal: true

module Ai
  module DuoCodeReview
    module Modes
      class Dap < Base
        def mode
          :dap
        end

        def enabled?
          true
        end

        def active?
          return false unless user
          return false unless container.duo_features_enabled

          # For Duo Enterprise: use duo agent platform only for internal GitLab users if feature flag is enabled
          return ::Feature.enabled?(:duo_code_review_dap_internal_users, user) if user_has_duo_enterprise_add_on?

          # For Duo Pro/Core: use agent platform if:
          # - user has duo_agent_platform access (checks user's add-on assignments)
          # - GA rollout is enabled OR experimental features are enabled
          # - DWS is configured (for self-managed)
          user.allowed_to_use?(:duo_agent_platform, root_namespace: container.root_ancestor) &&
            container.duo_code_review_dap_available? &&
            duo_agent_platform_configured?
        end

        private

        def user_has_duo_enterprise_add_on?
          if ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
            ::GitlabSubscriptions::AddOnPurchase
              .for_duo_enterprise
              .assigned_to_user(user)
              .exists?
          else
            ::GitlabSubscriptions::AddOnPurchase
              .for_self_managed
              .for_duo_enterprise
              .assigned_to_user(user)
              .exists?
          end
        end

        def duo_agent_platform_configured?
          feature_setting = selected_feature_setting

          # SaaS customers always have DWS available
          # Self-managed instances without a feature_setting record also default to cloud-connected models
          # Only self-managed instances with self_hosted? == true need further validation
          return true unless feature_setting&.self_hosted?

          # Self-hosted customers need compatible model and DWS configured
          return false if feature_setting.self_hosted_model&.unsupported_family_for_duo_agent_platform_code_review?

          ::Gitlab::DuoWorkflow::Client.self_hosted_url.present?
        end

        def selected_feature_setting
          # rubocop: disable CodeReuse/ServiceClass -- The service below should probably be a model too.
          service_result = ::Ai::FeatureSettingSelectionService.new(
            user,
            :duo_agent_platform,
            container.root_ancestor
          ).execute
          # rubocop: enable CodeReuse/ServiceClass

          service_result.success? ? service_result.payload : nil
        end
      end
    end
  end
end
