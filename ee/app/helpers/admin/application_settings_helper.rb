# frozen_string_literal: true

module Admin
  module ApplicationSettingsHelper
    extend self

    delegate :duo_availability,
      :instance_level_ai_beta_features_enabled,
      to: :'Gitlab::CurrentSettings.current_application_settings'

    def ai_powered_testing_agreement
      safe_format(
        s_('AIPoweredSM|By enabling this feature, you agree to the %{link_start}GitLab Testing Agreement%{link_end}.'),
        tag_pair_for_link(gitlab_testing_agreement_url))
    end

    def ai_powered_description
      safe_format(
        s_('AIPoweredSM|Enable %{link_start}AI-powered features%{link_end} for this instance.'),
        tag_pair_for_link(ai_powered_docs_url))
    end

    def direct_connections_description
      safe_format(
        s_('AIPoweredSM|Disable %{link_start}direct connections%{link_end} for this instance.'),
        tag_pair_for_link(direct_connections_docs_url))
    end

    def admin_display_ai_powered_chat_settings?
      License.feature_available?(:ai_chat) && CloudConnector::AvailableServices.find_by_name(:duo_chat).free_access?
    end

    def ai_settings_helper_data
      code_suggestions_purchased = CloudConnector::AvailableServices.find_by_name(:code_suggestions)&.purchased?
      disabled_direct_code_suggestions = ::Gitlab::CurrentSettings.disabled_direct_code_suggestions
      {
        duo_availability: duo_availability.to_s,
        experiment_features_enabled: instance_level_ai_beta_features_enabled.to_s,
        are_experiment_settings_allowed: "true",
        duo_pro_visible: code_suggestions_purchased.to_s,
        disabled_direct_connection_method: disabled_direct_code_suggestions.to_s,
        redirect_path: general_admin_application_settings_path
      }
    end

    private

    # rubocop:disable Gitlab/DocUrl
    # We want to link SaaS docs for flexibility for every URL related to Code Suggestions on Self Managed.
    # We expect to update docs often during the Beta and we want to point user to the most up to date information.
    def ai_powered_docs_url
      'https://docs.gitlab.com/ee/user/ai_features.html'
    end

    def gitlab_testing_agreement_url
      'https://about.gitlab.com/handbook/legal/testing-agreement/'
    end

    def direct_connections_docs_url
      'https://docs.gitlab.com/ee/user/project/repository/code_suggestions/index.html#disable-direct-connections-to-the-ai-gateway'
    end
    # rubocop:enable Gitlab/DocUrl

    def tag_pair_for_link(url)
      tag_pair(link_to('', url, target: '_blank', rel: 'noopener noreferrer'), :link_start, :link_end)
    end
  end
end
