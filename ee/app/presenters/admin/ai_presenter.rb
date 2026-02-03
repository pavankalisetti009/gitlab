# frozen_string_literal: true

module Admin
  class AiPresenter
    include Gitlab::Utils::StrongMemoize
    include GitlabSubscriptions::CodeSuggestionsHelper

    delegate :disabled_direct_code_suggestions?,
      :duo_availability,
      :enabled_expanded_logging,
      :gitlab_dedicated_instance?,
      :instance_level_ai_beta_features_enabled?,
      :model_prompt_cache_enabled?,
      to: :application_settings

    delegate :ai_gateway_url,
      :duo_agent_platform_service_url,
      :amazon_q_ready?,
      :duo_core_features_enabled?,
      :duo_workflow_service_account_user,
      to: :ai_settings

    delegate :subscription_name,
      :starts_at,
      :expires_at,
      to: :license

    def initialize(current_user)
      @current_user = current_user
    end

    def settings
      {
        ai_gateway_url: ai_gateway_url,
        duo_agent_platform_service_url: duo_agent_platform_service_url,
        expose_duo_agent_platform_service_url: expose_duo_agent_platform_service_url?,
        are_duo_core_features_enabled: duo_core_features_enabled?,
        are_experiment_settings_allowed: experiments_settings_allowed?,
        are_prompt_cache_settings_allowed: true,
        beta_self_hosted_models_enabled: beta_self_hosted_models_enabled,
        can_manage_self_hosted_models: can_manage_self_hosted_models?,
        can_manage_instance_model_selection: can_manage_instance_model_selection?,
        direct_code_suggestions_enabled: !disabled_direct_code_suggestions?,
        duo_availability: duo_availability,
        duo_workflow_enabled: duo_workflow_enabled?,
        enabled_expanded_logging: enabled_expanded_logging,
        experiment_features_enabled: instance_level_ai_beta_features_enabled?,
        is_bulk_add_on_assignment_enabled: true,
        is_saas: saas?,
        prompt_cache_enabled: model_prompt_cache_enabled?,
        subscription_name: subscription_name,
        gitlab_credits_dashboard_path: gitlab_credits_dashboard_path
      }.merge(duo_amazon_q_add_on_data, duo_paths)
        .transform_values(&:to_s)
        .merge(
          **duo_workflow_service_account,
          **duo_add_on_data
        )
    end

    private

    def expose_duo_agent_platform_service_url?
      ::Ability.allowed?(@current_user, :update_dap_self_hosted_model)
    end

    def duo_paths
      {
        add_duo_pro_seats_url: add_duo_pro_seats_url(subscription_name),
        duo_configuration_path: url_helpers.admin_gitlab_duo_configuration_index_path,
        duo_seat_utilization_path: url_helpers.admin_gitlab_duo_seat_utilization_index_path,
        duo_self_hosted_path: url_helpers.admin_gitlab_duo_self_hosted_index_path,
        duo_workflow_disable_path: url_helpers.disconnect_admin_ai_duo_workflow_settings_path,
        duo_workflow_settings_path: url_helpers.admin_ai_duo_workflow_settings_path,
        redirect_path: url_helpers.admin_gitlab_duo_path
      }
    end

    def duo_add_on_data
      {
        duo_add_on_end_date: duo_pro_or_duo_enterprise_add_on_purchase&.expires_on,
        duo_add_on_start_date: duo_pro_or_duo_enterprise_add_on_purchase&.started_at
      }
    end

    def duo_amazon_q_add_on_data
      return {} unless ::Ai::AmazonQ.feature_available?

      {
        amazon_q_auto_review_enabled: amazon_q_integration&.auto_review_enabled.present?,
        amazon_q_configuration_path: url_helpers.edit_admin_application_settings_integration_path(:amazon_q),
        amazon_q_ready: amazon_q_ready?
      }
    end

    def amazon_q_integration
      ::Integrations::AmazonQ.for_instance.first
    end

    def duo_workflow_enabled?
      ::Ai::DuoWorkflow.available?
    end

    def can_manage_instance_model_selection?
      ::Ability.allowed?(@current_user, :manage_instance_model_selection)
    end

    def saas?
      Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
    end

    def experiments_settings_allowed?
      ::GitlabSubscriptions::AddOnPurchase.active_duo_add_ons_exist?(:instance)
    end

    def beta_self_hosted_models_enabled
      ::Ai::TestingTermsAcceptance.has_accepted?
    end

    def can_manage_self_hosted_models?
      ::Ability.allowed?(@current_user, :manage_self_hosted_models_settings)
    end

    def duo_workflow_service_account
      {
        duo_workflow_service_account: duo_workflow_service_account_user
          &.slice(:id, :username, :name, :avatar_url)
          &.to_json
      }
    end

    def url_helpers
      Gitlab::Routing.url_helpers
    end

    def license
      License.current
    end
    strong_memoize_attr :license

    def application_settings
      Gitlab::CurrentSettings.expire_current_application_settings
      Gitlab::CurrentSettings.current_application_settings
    end
    strong_memoize_attr :application_settings

    def ai_settings
      ::Ai::Setting.instance
    end
    strong_memoize_attr :ai_settings

    def duo_pro_or_duo_enterprise_add_on_purchase
      ::GitlabSubscriptions::Duo.active_self_managed_duo_pro_or_enterprise
    end
    strong_memoize_attr :duo_pro_or_duo_enterprise_add_on_purchase

    def usage_billing_feature_available?
      return false unless Feature.enabled?(:usage_billing_dev, :instance)
      return false unless License.feature_available?(:usage_billing)
      return false if Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

      true
    end

    def gitlab_credits_dashboard_path
      return unless usage_billing_feature_available?

      url_helpers.admin_gitlab_credits_dashboard_index_path
    end
  end
end
