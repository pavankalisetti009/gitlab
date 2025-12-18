# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      class AvailabilityValidator
        def initialize(user:, resource:)
          @user = user
          # Either Project or Group
          @resource = resource
        end

        def available?
          return false unless ::Feature.enabled?(:duo_code_review_on_agent_platform, user)
          return false unless resource.duo_features_enabled

          # For Duo Enterprise: use duo agent platform only for internal GitLab users if feature flag is enabled
          return ::Feature.enabled?(:duo_code_review_dap_internal_users, user) if user_has_duo_enterprise_add_on?

          # For Duo Pro/Core: use agent platform if:
          # - user has duo_agent_platform access (checks user's add-on assignments)
          # - GA rollout is enabled OR experimental features are enabled
          # - DWS is configured (for self-managed)
          user.allowed_to_use?(:duo_agent_platform) &&
            (ga_rollout_enabled? || experimental_features_enabled?) &&
            duo_agent_platform_configured?
        end

        private

        attr_reader :user, :resource

        def user_has_duo_enterprise_add_on?
          ::GitlabSubscriptions::AddOnPurchase.for_active_add_ons([:duo_enterprise], user).exists?
        end

        def ga_rollout_enabled?
          ::Gitlab::Llm::Utils::AiFeaturesCatalogue.effective_maturity(:duo_agent_platform) == :ga
        end

        def experimental_features_enabled?
          if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
            resource.root_ancestor.experiment_features_enabled
          else
            ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
          end
        end

        def duo_agent_platform_configured?
          return false unless resource.duo_foundational_flows_enabled

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
          service_result = ::Ai::FeatureSettingSelectionService.new(
            user,
            :duo_agent_platform,
            resource.root_ancestor
          ).execute

          service_result.success? ? service_result.payload : nil
        end
      end
    end
  end
end
