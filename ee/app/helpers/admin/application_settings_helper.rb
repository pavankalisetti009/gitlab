# frozen_string_literal: true

module Admin
  module ApplicationSettingsHelper
    extend self

    delegate :duo_availability,
      :instance_level_ai_beta_features_enabled,
      :enabled_expanded_logging,
      to: :current_application_settings

    def admin_display_duo_addon_settings?
      GitlabSubscriptions::AddOnPurchase.for_self_managed.for_duo_pro_or_duo_enterprise.active.any?
    end

    def admin_duo_home_app_data
      subscription_name = License.current.subscription_name
      {
        duo_seat_utilization_path: admin_gitlab_duo_seat_utilization_index_path,
        duo_configuration_path: admin_gitlab_duo_configuration_index_path,
        add_duo_pro_seats_url: add_duo_pro_seats_url(subscription_name),
        subscription_name: subscription_name,
        is_bulk_add_on_assignment_enabled: 'true',
        subscription_start_date: License.current.starts_at,
        subscription_end_date: License.current.expires_at,
        duo_availability: duo_availability,
        direct_code_suggestions_enabled: direct_code_suggestions_enabled?.to_s,
        experiment_features_enabled: instance_level_ai_beta_features_enabled.to_s,
        beta_self_hosted_models_enabled: ::Ai::TestingTermsAcceptance.has_accepted?.to_s,
        are_experiment_settings_allowed: experiments_settings_allowed?.to_s
      }.merge(duo_add_on_data)
    end

    def duo_add_on_data
      duo_purchase = GitlabSubscriptions::AddOnPurchase.for_self_managed.for_duo_pro_or_duo_enterprise.last

      {
        duo_add_on_start_date: duo_purchase&.started_at,
        duo_add_on_end_date: duo_purchase&.expires_on
      }
    end

    def admin_ai_general_settings_helper_data
      {
        on_general_settings_page: 'true',
        configuration_settings_path: admin_gitlab_duo_path,
        show_redirect_banner: 'true'
      }
    end

    def admin_ai_configuration_settings_helper_data
      {
        on_general_settings_page: 'false',
        redirect_path: admin_gitlab_duo_path
      }.merge(ai_settings_helper_data)
    end

    def ai_settings_helper_data
      code_suggestions_purchased = CloudConnector::AvailableServices.find_by_name(:code_suggestions)&.purchased?
      disabled_direct_code_suggestions = ::Gitlab::CurrentSettings.disabled_direct_code_suggestions
      beta_self_hosted_models_enabled = ::Ai::TestingTermsAcceptance.has_accepted?
      can_manage_self_hosted_models =
        ::License.current&.ultimate? && ::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.active.exists?
      ai_gateway_url = ::Ai::Setting.instance.ai_gateway_url

      {
        duo_availability: duo_availability.to_s,
        experiment_features_enabled: instance_level_ai_beta_features_enabled.to_s,
        enabled_expanded_logging: enabled_expanded_logging.to_s,
        are_experiment_settings_allowed: experiments_settings_allowed?.to_s,
        duo_pro_visible: code_suggestions_purchased.to_s,
        disabled_direct_connection_method: disabled_direct_code_suggestions.to_s,
        beta_self_hosted_models_enabled: beta_self_hosted_models_enabled.to_s,
        toggle_beta_models_path: admin_ai_duo_self_hosted_toggle_beta_models_path,
        can_manage_self_hosted_models: can_manage_self_hosted_models.to_s,
        ai_gateway_url: ai_gateway_url
      }
    end

    private

    def current_application_settings
      # clear cached settings so that duo_availability shows up correctly
      Gitlab::CurrentSettings.expire_current_application_settings

      Gitlab::CurrentSettings.current_application_settings
    end

    # rubocop:disable Gitlab/DocumentationLinks/HardcodedUrl
    # We want to link SaaS docs for flexibility for every URL related to Code Suggestions on Self Managed.
    # We expect to update docs often during the Beta and we want to point user to the most up to date information.
    def ai_powered_docs_url
      'https://docs.gitlab.com/ee/user/ai_features.html'
    end

    def gitlab_testing_agreement_url
      'https://about.gitlab.com/handbook/legal/testing-agreement/'
    end

    def direct_connections_docs_url
      'https://docs.gitlab.com/ee/user/project/repository/code_suggestions/#direct-and-indirect-connections'
    end
    # rubocop:enable Gitlab/DocumentationLinks/HardcodedUrl

    def tag_pair_for_link(url)
      tag_pair(link_to('', url, target: '_blank', rel: 'noopener noreferrer'), :link_start, :link_end)
    end

    def experiments_settings_allowed?
      CloudConnector::AvailableServices.find_by_name(:anthropic_proxy)&.purchased?
    end

    def direct_code_suggestions_enabled?
      !::Gitlab::CurrentSettings.disabled_direct_code_suggestions
    end
  end
end
