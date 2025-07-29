# frozen_string_literal: true

module MemberRolesHelper
  include Gitlab::Utils::StrongMemoize
  include ::GitlabSubscriptions::SubscriptionHelper

  def member_roles_data(group = nil)
    {
      new_role_path: new_role_path(group),
      group_full_path: group&.full_path,
      group_id: group&.id,
      current_user_email: current_user.notification_email_or_default,
      ldap_users_path: ldap_enabled? ? admin_users_path(filter: 'ldap_sync') : nil,
      ldap_servers: ldap_servers&.to_json,
      is_saas: gitlab_com_subscription?.to_s,
      admin_mode_setting_path: (admin_mode_setting_path unless group)
    }.compact
  end

  def manage_member_roles_path(source)
    root_group = source&.root_ancestor
    return unless root_group&.custom_roles_enabled?

    if gitlab_com_subscription? && can?(current_user, :admin_group_member, root_group)
      group_settings_roles_and_permissions_path(root_group)
    elsif current_user&.can_admin_all_resources?
      admin_application_settings_roles_and_permissions_path
    end
  end

  def member_role_edit_path(role)
    if use_group_path?(role)
      Gitlab::Routing.url_helpers.edit_group_settings_roles_and_permission_path(role.namespace, role)
    else
      Gitlab::Routing.url_helpers.edit_admin_application_settings_roles_and_permission_path(role)
    end
  end

  def member_role_details_path(role)
    if use_group_path?(role)
      Gitlab::Routing.url_helpers.group_settings_roles_and_permission_path(role.namespace, role)
    else
      Gitlab::Routing.url_helpers.admin_application_settings_roles_and_permission_path(role)
    end
  end

  private

  def use_group_path?(role)
    return false unless gitlab_com_subscription?
    return true if role.is_a?(String)

    !role.admin_related_role?
  end

  def new_role_path(source)
    root_group = source&.root_ancestor

    if gitlab_com_subscription? && can?(current_user, :admin_member_role, root_group)
      new_group_settings_roles_and_permission_path(root_group)
    elsif !gitlab_com_subscription? && can?(current_user, :admin_member_role)
      new_admin_application_settings_roles_and_permission_path
    end
  end

  def ldap_enabled?
    !gitlab_com_subscription? && Gitlab::Auth::Ldap::Config.enabled? && can?(current_user, :manage_ldap_admin_links)
  end

  def ldap_servers
    return unless ldap_enabled?

    ::Gitlab::Auth::Ldap::Config.available_servers.map { |server| { text: server.label, value: server.provider_name } }
  end

  def admin_mode_setting_path
    return unless MemberRole.admin.any? && !Gitlab::CurrentSettings.admin_mode

    general_admin_application_settings_path(anchor: 'js-signin-settings')
  end
  strong_memoize_attr :admin_mode_setting_path
end
