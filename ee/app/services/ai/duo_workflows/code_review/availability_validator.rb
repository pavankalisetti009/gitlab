# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      class AvailabilityValidator
        def initialize(user:, merge_request:)
          @user = user
          @merge_request = merge_request
          @project = merge_request.project
        end

        def available?
          return false unless ::Feature.enabled?(:duo_code_review_on_agent_platform, user)
          return false unless project.duo_features_enabled
          return false unless ::Ability.allowed?(user, :create_note, merge_request)

          # For Duo Enterprise: use duo agent platform only for internal GitLab users if feature flag is enabled
          return ::Feature.enabled?(:duo_code_review_dap_internal_users, user) if user_has_duo_enterprise_add_on?

          # For Duo Pro/Core: use agent platform if:
          # - user has duo_agent_platform access (checks user's add-on assignments)
          # - experimental features are enabled
          # - DWS is configured (for self-managed)
          user.allowed_to_use?(:duo_agent_platform) && experimental_features_enabled? && duo_agent_platform_configured?
        end

        private

        attr_reader :user, :merge_request, :project

        def user_has_duo_enterprise_add_on?
          ::GitlabSubscriptions::AddOnPurchase.for_active_add_ons([:duo_enterprise], user).exists?
        end

        def experimental_features_enabled?
          if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
            project.root_ancestor.experiment_features_enabled
          else
            ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
          end
        end

        def duo_agent_platform_configured?
          feature_setting = ::Ai::FeatureSetting.find_by_feature('review_merge_request')

          # SaaS customers always have DWS available
          # Self-managed instances without a feature_setting record also default to cloud-connected models
          # Only self-managed instances with self_hosted? == true need further validation
          return true unless feature_setting&.self_hosted?

          # Self-hosted customers need compatible model and DWS configured
          return false if feature_setting.self_hosted_model&.unsupported_family_for_duo_agent_platform_code_review?

          ::Gitlab::DuoWorkflow::Client.self_hosted_url.present?
        end
      end
    end
  end
end
