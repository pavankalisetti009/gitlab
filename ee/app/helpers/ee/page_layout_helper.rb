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

      {
        user_id: user.to_global_id,
        project_id: (project.to_global_id if project&.persisted?),
        namespace_id: (group.to_global_id if group&.persisted?),
        root_namespace_id: ::Gitlab::Llm::TanukiBot.root_namespace_id,
        resource_id: ::Gitlab::Llm::TanukiBot.resource_id,
        metadata: ::Gitlab::DuoWorkflow::Client.metadata(user).to_json,
        user_model_selection_enabled: user_model_selection_enabled.to_s,
        agentic_available: is_agentic_available.to_s,
        chat_title: chat_title,
        expanded: ('true' if ai_panel_expanded?)
      }
    end
  end
end
