# frozen_string_literal: true

module EE
  module PageLayoutHelper
    def duo_chat_panel_data(user, project, group)
      group ||= user.user_preference.get_default_duo_namespace unless project

      user_model_selection_enabled = ::Gitlab::Llm::TanukiBot.user_model_selection_enabled?(user: user)
      chat_title = ::Ai::AmazonQ.enabled? ? s_('GitLab Duo Chat with Amazon Q') : s_('GitLab Duo Chat')
      is_agentic_available = ::Gitlab::Llm::TanukiBot.agentic_mode_available?(
        user: user, project: project, group: group
      )
      chat_disabled_reason = ::Gitlab::Llm::TanukiBot.chat_disabled_reason(
        user: user, container: project || group
      )

      {
        user_id: user.to_global_id,
        project_id: (project.to_global_id if project&.persisted?),
        namespace_id: (group.to_global_id if group&.persisted?),
        root_namespace_id: ::Gitlab::Llm::TanukiBot.root_namespace_id,
        resource_id: ::Gitlab::Llm::TanukiBot.resource_id,
        metadata: ::Gitlab::DuoWorkflow::Client.metadata(user).to_json,
        user_model_selection_enabled: user_model_selection_enabled.to_s,
        agentic_available: is_agentic_available.to_s,
        agentic_unavailable_message: agentic_unavailable_message(user, project || group, is_agentic_available),
        chat_title: chat_title,
        chat_disabled_reason: chat_disabled_reason.to_s,
        expanded: ('true' if ai_panel_expanded?)
      }
    end

    # rubocop:disable Layout/LineLength -- i18n
    def agentic_unavailable_message(user, container, is_agentic_available)
      return if is_agentic_available

      response = user.allowed_to_use(:duo_chat)

      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        if response.allowed? && container.nil?
          case response.enablement_type
          when "duo_enterprise", "duo_pro"
            preferences_url = '/-/profile/preferences#user_user_preference_attributes_default_duo_add_on_assignment_id'
            preferences_link = link_to('', preferences_url)
            return safe_format(
              s_('DuoChat|Duo Agentic Chat is not available at the moment in this page. To work with Duo Agentic Chat in pages outside the scope of a project please select a %{strong_start}Default GitLab Duo namespace%{strong_end} in your %{preferences_link_start}User Profile Preferences%{preferences_link_end}.'),
              tag_pair(content_tag(:strong, ''), :strong_start, :strong_end).merge(
                tag_pair(preferences_link, :preferences_link_start, :preferences_link_end)
              )
            )
          when "duo_core"
            return s_("DuoChat|Duo Agentic Chat is not available in this page, please visit a project page to have access to chat.")
          end
        end

        s_("DuoChat|You don't currently have access to Duo Chat, please contact your GitLab administrator.")
      else # rubocop:disable Style/EmptyElse -- to be implemented
        # TODO: self-managed logic: https://gitlab.com/gitlab-org/gitlab/-/issues/562168
      end
    end
    # rubocop:enable Layout/LineLength
  end
end
