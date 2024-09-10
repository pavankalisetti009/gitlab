# frozen_string_literal: true

module EE
  module Groups
    module SettingsHelper
      def saas_user_caps_help_text(group)
        project_sharing_docs_url = help_page_path('user/group/access_and_permissions', anchor: 'prevent-a-project-from-being-shared-with-groups')
        group_sharing_docs_url = help_page_path('user/group/access_and_permissions', anchor: 'prevent-group-sharing-outside-the-group-hierarchy')

        project_sharing_docs_link_start = '<a href="%{url}" target="_blank" rel="noopener noreferrer">'.html_safe % { url: project_sharing_docs_url }
        group_sharing_docs_link_start = '<a href="%{url}" target="_blank" rel="noopener noreferrer">'.html_safe % { url: group_sharing_docs_url }

        ERB::Util.html_escape(saas_user_caps_i18n_string(group)) % { project_sharing_docs_link_start: project_sharing_docs_link_start, group_sharing_docs_link_start: group_sharing_docs_link_start, link_end: '</a>'.html_safe }
      end

      def unique_project_download_limit_settings_data
        settings = @group.namespace_settings || ::NamespaceSetting.new
        limit = settings.unique_project_download_limit
        interval = settings.unique_project_download_limit_interval_in_seconds
        allowlist = settings.unique_project_download_limit_allowlist
        alertlist = settings.unique_project_download_limit_alertlist
        auto_ban_users = settings.auto_ban_user_on_excessive_projects_download

        {
          group_full_path: @group.full_path,
          max_number_of_repository_downloads: limit,
          max_number_of_repository_downloads_within_time_period: interval,
          git_rate_limit_users_allowlist: allowlist,
          git_rate_limit_users_alertlist: alertlist,
          auto_ban_user_on_excessive_projects_download: auto_ban_users.to_s
        }
      end

      def show_group_ai_settings?
        @group.licensed_ai_features_available?
      end

      def group_ai_settings_helper_data
        cascading_settings_data = cascading_namespace_settings_tooltip_data(:duo_features_enabled, @group, method(:edit_group_path))[:tooltip_data]
        {
          cascading_settings_data: cascading_settings_data,
          duo_availability: @group.namespace_settings.duo_availability.to_s,
          are_duo_settings_locked: @group.namespace_settings.duo_features_enabled_locked?.to_s,
          experiment_features_enabled: @group.namespace_settings.experiment_features_enabled.to_s,
          are_experiment_settings_allowed: @group.experiment_settings_allowed?.to_s,
          redirect_path: edit_group_path(@group),
          update_id: @group.id
        }
      end

      def seat_controls_disabled_help_text(group)
        if ::Feature.enabled?(:block_seat_overages, group)
          _("Restricted access and user cap cannot be turned on. The group or one of its subgroups or projects is shared externally.")
        else
          _("User cap cannot be turned on. The group or one of its subgroups or projects is shared externally.")
        end
      end

      private

      def saas_user_caps_i18n_string(group)
        if ::Feature.enabled?(:saas_user_caps_auto_approve_pending_users_on_cap_increase, group.root_ancestor)
          s_('GroupSettings|After the instance reaches the user cap, any user who is added or requests access must be approved by an administrator. Leave empty for an unlimited user cap. If you change the user cap to unlimited, you must re-enable %{project_sharing_docs_link_start}project sharing%{link_end} and %{group_sharing_docs_link_start}group sharing%{link_end}.')
        else
          s_('GroupSettings|After the instance reaches the user cap, any user who is added or requests access must be approved by an administrator. Leave empty for an unlimited user cap. If you change the user cap to unlimited, you must re-enable %{project_sharing_docs_link_start}project sharing%{link_end} and %{group_sharing_docs_link_start}group sharing%{link_end}. Increasing the user cap does not automatically approve pending users.')
        end
      end
    end
  end
end
