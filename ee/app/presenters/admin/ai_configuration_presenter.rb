# frozen_string_literal: true

module Admin
  class AiConfigurationPresenter
    include Gitlab::Utils::StrongMemoize

    delegate :disabled_direct_code_suggestions?,
      :duo_availability,
      :duo_remote_flows_availability,
      :duo_foundational_flows_availability,
      :duo_chat_expiration_column,
      :duo_chat_expiration_days,
      :duo_workflows_default_image_registry,
      :enabled_expanded_logging,
      :gitlab_dedicated_instance?,
      :instance_level_ai_beta_features_enabled,
      :model_prompt_cache_enabled?,
      to: :application_settings

    delegate :ai_gateway_url,
      :ai_gateway_timeout_seconds,
      :duo_agent_platform_service_url,
      :duo_agent_platform_enabled,
      :duo_core_features_enabled?,
      :foundational_agents_default_enabled,
      :ai_minimum_access_level_execute_with_fallback,
      :ai_minimum_access_level_execute_async_with_fallback,
      to: :ai_settings

    def initialize(current_user)
      @current_user = current_user
    end

    def settings
      settings_hash = {
        ai_gateway_url: ai_gateway_url,
        ai_gateway_timeout_seconds: ai_gateway_timeout_seconds,
        duo_agent_platform_service_url: duo_agent_platform_service_url,
        expose_duo_agent_platform_service_url: expose_duo_agent_platform_service_url?,
        are_experiment_settings_allowed: active_duo_add_ons_exist?,
        are_prompt_cache_settings_allowed: true,
        beta_self_hosted_models_enabled: beta_self_hosted_models_enabled,
        can_manage_self_hosted_models: can_manage_self_hosted_models?,
        can_configure_ai_logging: can_configure_ai_logging?,
        disabled_direct_connection_method: disabled_direct_code_suggestions?,
        duo_availability: duo_availability,
        duo_agent_platform_enabled: duo_agent_platform_enabled,
        duo_remote_flows_availability: duo_remote_flows_availability,
        duo_foundational_flows_availability: duo_foundational_flows_availability,
        duo_workflows_default_image_registry: duo_workflows_default_image_registry,
        duo_chat_expiration_column: duo_chat_expiration_column,
        duo_chat_expiration_days: duo_chat_expiration_days,
        duo_core_features_enabled: duo_core_features_enabled?,
        duo_pro_visible: active_duo_add_ons_exist?,
        enabled_expanded_logging: enabled_expanded_logging,
        experiment_features_enabled: instance_level_ai_beta_features_enabled,
        on_general_settings_page: false,
        prompt_cache_enabled: model_prompt_cache_enabled?,
        redirect_path: url_helpers.admin_gitlab_duo_path,
        toggle_beta_models_path: url_helpers.admin_ai_duo_self_hosted_toggle_beta_models_path,
        foundational_agents_default_enabled: foundational_agents_default_enabled,
        show_foundational_agents_availability: true,
        show_foundational_agents_per_agent_availability: show_foundational_agents_per_agent_availability?,
        show_duo_agent_platform_enablement_setting: true,
        foundational_agents_statuses: Gitlab::Json.dump(foundational_agents_statuses),
        ai_minimum_access_level_to_execute: ai_minimum_access_level_execute_with_fallback,
        ai_minimum_access_level_to_execute_async: ai_minimum_access_level_execute_async_with_fallback
      }

      settings_hash[:namespace_access_rules] = Gitlab::Json.dump(namespace_access_rules) if Feature.enabled?(
        :duo_access_through_namespaces, :instance)

      settings_hash.transform_values(&:to_s)
    end

    private

    def namespace_access_rules
      rules = ::Ai::FeatureAccessRule.duo_root_namespace_access_rules

      ::Ai::FeatureAccessRuleTransformer.transform(rules)
    end

    def expose_duo_agent_platform_service_url?
      ::Ability.allowed?(@current_user, :update_dap_self_hosted_model)
    end

    def show_foundational_agents_per_agent_availability?
      ::Feature.enabled?(:duo_foundational_agents_per_agent_availability, :instance)
    end

    def active_duo_add_ons_exist?
      ::GitlabSubscriptions::AddOnPurchase.active_duo_add_ons_exist?(:instance)
    end

    def beta_self_hosted_models_enabled
      ::Ai::TestingTermsAcceptance.has_accepted?
    end

    def can_manage_self_hosted_models?
      ::Ability.allowed?(@current_user, :manage_self_hosted_models_settings)
    end

    def can_configure_ai_logging?
      return false if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      return false if gitlab_dedicated_instance?

      ::License.ai_features_available?
    end

    def url_helpers
      Gitlab::Routing.url_helpers
    end

    def application_settings
      Gitlab::CurrentSettings.expire_current_application_settings
      Gitlab::CurrentSettings.current_application_settings
    end
    strong_memoize_attr :application_settings

    def foundational_agents_statuses
      ::Organizations::Organization.default_organization&.foundational_agents_statuses
    end

    def ai_settings
      ::Ai::Setting.instance
    end
    strong_memoize_attr :ai_settings
  end
end
