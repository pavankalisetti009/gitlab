# frozen_string_literal: true

module EE
  module GlobalPolicy
    extend ActiveSupport::Concern

    prepended do
      include ::Gitlab::Utils::StrongMemoize

      condition(:operations_dashboard_available) do
        License.feature_available?(:operations_dashboard)
      end

      condition(:pages_size_limit_available) do
        License.feature_available?(:pages_size_limit)
      end

      condition(:export_user_permissions_available) do
        ::License.feature_available?(:export_user_permissions)
      end

      condition(:top_level_group_creation_enabled) do
        next true if ::Gitlab.com? && @user&.can_admin_all_resources?

        ::Gitlab::CurrentSettings.top_level_group_creation_enabled?
      end

      condition(:clickhouse_main_database_available) do
        ::Gitlab::ClickHouse.configured?
      end

      condition(:instance_devops_adoption_available) do
        ::License.feature_available?(:instance_level_devops_adoption)
      end

      condition(:runner_performance_insights_available) do
        ::License.feature_available?(:runner_performance_insights)
      end

      condition(:runner_upgrade_management_available) do
        License.feature_available?(:runner_upgrade_management)
      end

      condition(:service_accounts_available) do
        ::License.feature_available?(:service_accounts)
      end

      condition(:instance_external_audit_events_enabled) do
        ::License.feature_available?(:external_audit_events)
      end

      condition(:code_suggestions_licensed) do
        next true if ::Gitlab.org_or_com?

        ::License.feature_available?(:code_suggestions)
      end

      condition(:code_suggestions_enabled_for_user) do
        next false unless @user

        @user.allowed_to_use?(:code_suggestions)
      end

      condition(:ai_features_banned) do
        ::Gitlab::CurrentSettings.duo_never_on?
      end

      condition(:user_allowed_to_use_glab_ask_git_command) do
        @user.allowed_to_use?(:glab_ask_git_command, licensed_feature: :glab_ask_git_command)
      end

      rule { ~ai_features_banned & user_allowed_to_use_glab_ask_git_command }.policy do
        enable :access_glab_ask_git_command
      end

      condition(:duo_chat_enabled_for_user) do
        @user.allowed_to_use?(:duo_chat)
      end

      condition(:duo_agentic_chat_enabled) do
        ::Feature.enabled?(:duo_agentic_chat, @user)
      end

      condition(:instance_with_self_hosted_duo) do
        ::Ai::Setting.self_hosted?
      end

      condition(:agentic_chat_on_self_hosted_duo_not_configured_via_feature_setting) do
        Ai::FeatureSetting.duo_agent_platform.self_hosted.empty?
      end

      condition(:agentic_chat_on_self_hosted_duo_feature_flag_disabled) do
        ::Feature.disabled?(:self_hosted_agent_platform, :instance)
      end

      condition(:user_belongs_to_paid_namespace) do
        next false unless @user

        @user.belongs_to_paid_namespace?
      end

      condition(:custom_roles_allowed) do
        ::License.feature_available?(:custom_roles)
      end

      condition(:default_roles_assignees_allowed) do
        ::License.feature_available?(:default_roles_assignees)
      end

      condition(:instance_model_configuration_allowed, scope: :global) do
        ::License.feature_available?(:self_hosted_models) &&
          ::GitlabSubscriptions::AddOnPurchase.for_self_managed.for_duo_enterprise.active.exists?
      end

      condition(:self_hosted_models_allowed, scope: :global) do
        next false if ::Feature.disabled?(:allow_self_hosted_features_for_com, :instance) &&
          ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

        next false if ::Gitlab::CurrentSettings.gitlab_dedicated_instance?

        next false if ::Ai::AmazonQ.connected?

        true
      end

      condition(:instance_model_selection_available) do
        next false unless ::Feature.enabled?(:instance_level_model_selection, :instance)
        next false if ::Ai::AmazonQ.connected?

        !::License.current&.offline_cloud_license?
      end

      condition(:x_ray_available) do
        next true if ::Gitlab::Saas.feature_available?(:code_suggestions_x_ray)

        ::License.feature_available?(:code_suggestions)
      end

      rule { x_ray_available }.enable :access_x_ray_on_instance

      rule { ~anonymous & operations_dashboard_available }.enable :read_operations_dashboard

      condition(:remote_development_feature_licensed) do
        License.feature_available?(:remote_development)
      end

      condition(:has_admin_custom_role, scope: :user) do
        MemberRole.all_customizable_admin_permission_keys.any? do |ability|
          custom_role_ability(@user).allowed?(ability)
        end
      end

      MemberRole.all_customizable_admin_permission_keys.each do |ability|
        desc "Admin custom role that enables #{ability.to_s.tr('_', ' ')}"
        condition(:"custom_role_enables_#{ability}") do
          custom_role_ability(@user).allowed?(ability)
        end
      end

      condition(:duo_core_features_available) do
        License.duo_core_features_available?
      end

      condition(:data_management_available) do
        License.feature_available?(:data_management) && ::Feature.enabled?(:geo_primary_verification_view, @user)
      end

      rule { ~anonymous & remote_development_feature_licensed }.policy do
        enable :access_workspaces_feature
      end

      rule { admin & instance_devops_adoption_available }.policy do
        enable :manage_devops_adoption_namespaces
        enable :view_instance_devops_adoption
      end

      rule { admin }.policy do
        enable :delete_license
        enable :manage_subscription
        enable :read_admin_subscription
        enable :read_admin_data_management
        enable :read_all_geo
        enable :read_all_workspaces
        enable :read_cloud_connector_status
        enable :read_jobs_statistics
        enable :read_licenses
        enable :read_runner_usage
        enable :manage_ldap_admin_links
        enable :manage_self_hosted_models_settings
        enable :manage_instance_model_selection
      end

      rule { ~instance_model_configuration_allowed }.policy do
        prevent :manage_self_hosted_models_settings
        prevent :manage_instance_model_selection
      end

      rule { ~self_hosted_models_allowed }.prevent :manage_self_hosted_models_settings
      rule { ~instance_model_selection_available }.prevent :manage_instance_model_selection

      rule { admin & custom_roles_allowed }.policy do
        enable :admin_member_role
        enable :view_member_roles
        enable :read_admin_role
        enable :create_admin_role
      end

      rule { admin & default_roles_assignees_allowed }.policy do
        enable :view_member_roles
      end

      rule { ~anonymous & custom_roles_allowed }.policy do
        enable :read_member_role
      end

      rule { admin & pages_size_limit_available }.enable :update_max_pages_size

      rule { ~runner_performance_insights_available }.policy do
        prevent :read_jobs_statistics
        prevent :read_runner_usage
      end

      rule { ~clickhouse_main_database_available }.prevent :read_runner_usage

      rule { admin & service_accounts_available }.enable :admin_service_accounts

      rule { ~anonymous }.policy do
        enable :view_productivity_analytics
      end

      rule { ~(admin | allow_to_manage_default_branch_protection) }.policy do
        prevent :create_group_with_default_branch_protection
      end

      rule { export_user_permissions_available & admin }.enable :export_user_permissions

      rule { can?(:create_group) }.enable :create_group_via_api
      rule { ~top_level_group_creation_enabled }.prevent :create_group_via_api

      rule { admin & instance_external_audit_events_enabled }.policy do
        enable :admin_instance_external_audit_events
      end

      rule do
        code_suggestions_licensed & ~ai_features_banned & code_suggestions_enabled_for_user
      end.enable :access_code_suggestions

      rule { duo_chat_enabled_for_user & ~ai_features_banned }.enable :access_duo_chat
      rule { can?(:access_duo_chat) & duo_agentic_chat_enabled }.enable :access_duo_agentic_chat
      rule { runner_upgrade_management_available | user_belongs_to_paid_namespace }.enable :read_runner_upgrade_status

      rule { security_policy_bot }.policy do
        enable :access_git
      end

      rule { has_admin_custom_role }.policy do
        enable :access_admin_area
        enable :read_application_statistics
      end

      rule { custom_role_enables_read_admin_cicd }.policy do
        enable :read_admin_cicd
      end

      rule { custom_role_enables_read_admin_monitoring }.policy do
        enable :read_admin_background_migrations
        enable :read_admin_data_management
        enable :read_admin_gitaly_servers
        enable :read_admin_health_check
        enable :read_admin_system_information
      end

      rule { custom_role_enables_read_admin_subscription }.policy do
        enable :read_admin_subscription
        enable :read_billable_member
        enable :read_licenses
      end

      rule { custom_role_enables_read_admin_users }.policy do
        enable :read_admin_users
      end

      rule { custom_role_enables_read_admin_groups }.policy do
        enable :read_admin_groups
      end

      rule { custom_role_enables_read_admin_projects }.policy do
        enable :read_admin_projects
      end

      rule { admin & duo_core_features_available }.policy do
        enable :manage_duo_core_settings
      end

      condition(:third_party_agents_enabled) do
        ::Feature.enabled?(:agent_platform_claude_code, @user)
      end

      condition(:direct_access_enabled) do
        !::Gitlab::CurrentSettings.disabled_direct_code_suggestions
      end

      condition(:allowed_to_use_model_proxy, scope: :user) do
        @user.allowed_to_use?(:duo_agent_platform, unit_primitive_name: :ai_gateway_model_provider_proxy)
      end

      rule { third_party_agents_enabled & direct_access_enabled & allowed_to_use_model_proxy }.policy do
        enable :duo_generate_direct_access_token
      end

      rule { ~data_management_available }.prevent :read_admin_data_management
    end

    # Check whether a user is allowed to use Duo Chat powered by self-hosted models
    def duo_chat_self_hosted?
      ::Ai::FeatureSetting.find_by_feature(:duo_chat)&.self_hosted?
    end

    def custom_role_ability(user)
      strong_memoize_with(:custom_role_ability, user) do
        ::Authz::CustomAbility.new(user)
      end
    end
  end
end
