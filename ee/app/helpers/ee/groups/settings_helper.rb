# frozen_string_literal: true

module EE
  module Groups
    module SettingsHelper
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

      def show_group_ai_settings_general?
        GitlabSubscriptions::Duo.duo_settings_available?(@group.root_ancestor)
      end

      def show_group_ai_settings_page?
        @group.licensed_ai_features_available? && show_gitlab_duo_settings_app?(@group)
      end

      def show_virtual_registries_setting?(group)
        ::Feature.enabled?(:maven_virtual_registry, group) &&
          group.licensed_feature_available?(:packages_virtual_registry) &&
          can?(current_user, :admin_virtual_registry, group.virtual_registry_policy_subject)
      end

      def group_ai_general_settings_helper_data
        {
          on_general_settings_page: 'true',
          redirect_path: edit_group_path(@group)
        }.merge(group_ai_settings_helper_data)
      end

      def group_ai_configuration_settings_helper_data
        {
          on_general_settings_page: 'false',
          redirect_path: group_settings_gitlab_duo_path(@group)
        }.merge(group_ai_settings_helper_data)
      end

      def group_ai_settings_helper_data
        duo_cascading_settings_data.merge(duo_feature_settings_data)
      end

      def group_amazon_q_settings_view_model_data
        {
          group_id: @group.id.to_s,
          init_availability: @group.namespace_settings.duo_availability.to_s,
          init_auto_review_enabled: @group.amazon_q_integration&.auto_review_enabled.present?,
          are_duo_settings_locked: @group.namespace_settings.duo_features_enabled_locked?,
          duo_availability_cascading_settings: cascading_namespace_settings_tooltip_raw_data(:duo_features_enabled, @group, method(:edit_group_path))
        }
      end

      def group_amazon_q_settings_view_model_json
        ::Gitlab::Json.generate(group_amazon_q_settings_view_model_data.deep_transform_keys { |k| k.to_s.camelize(:lower) })
      end

      def seat_control_disabled_help_text
        _("Restricted access and user cap cannot be turned on. The group or one of its subgroups or projects is shared externally.")
      end

      private

      def duo_cascading_settings_data
        {
          duo_availability_cascading_settings: cascading_tooltip_data(:duo_features_enabled),
          duo_remote_flows_cascading_settings: cascading_tooltip_data(:duo_remote_flows_enabled),
          duo_foundational_flows_cascading_settings: cascading_tooltip_data(:duo_foundational_flows_enabled)
        }
      end

      def duo_feature_settings_data
        {
          duo_availability: @group.namespace_settings.duo_availability.to_s,
          are_duo_settings_locked: @group.namespace_settings.duo_features_enabled_locked?.to_s,
          experiment_features_enabled: @group.namespace_settings.experiment_features_enabled.to_s,
          duo_core_features_enabled: @group.namespace_settings.duo_core_features_enabled.to_s,
          prompt_cache_enabled: @group.namespace_settings.model_prompt_cache_enabled.to_s,
          are_experiment_settings_allowed: (@group.experiment_settings_allowed? && gitlab_com_subscription?).to_s,
          are_prompt_cache_settings_allowed: (@group.prompt_cache_settings_allowed? && gitlab_com_subscription?).to_s,
          update_id: @group.id,
          is_saas: saas?.to_s
        }.merge(
          duo_workflow_settings_data,
          ai_access_level_settings_data,
          foundational_flows_settings_data,
          foundational_agents_data,
          namespace_access_rules_data
        )
      end

      def duo_workflow_settings_data
        {
          duo_agent_platform_enabled: @group.duo_agent_platform_enabled.to_s,
          duo_workflow_available: (@group.root? && current_user.can?(:admin_duo_workflow, @group)).to_s,
          duo_workflow_mcp_enabled: @group.duo_workflow_mcp_enabled.to_s,
          ai_usage_data_collection_available: @group.root?.to_s,
          ai_usage_data_collection_enabled: @group.ai_usage_data_collection_enabled.to_s,
          prompt_injection_protection_level: @group.prompt_injection_protection_level.to_s,
          prompt_injection_protection_available: (::Feature.enabled?(:ai_prompt_scanning, current_user) && current_user.can?(:admin_duo_workflow, @group)).to_s,
          show_duo_agent_platform_enablement_setting: show_duo_agent_platform_enablement_setting?.to_s
        }
      end

      def ai_access_level_settings_data
        {
          ai_minimum_access_level_to_execute: @group.ai_minimum_access_level_execute_with_fallback,
          ai_minimum_access_level_to_execute_async: @group.ai_minimum_access_level_execute_async_with_fallback,
          ai_settings_minimum_access_level_manage: @group.ai_minimum_access_level_manage,
          ai_settings_minimum_access_level_enable_on_projects: @group.ai_minimum_access_level_enable_on_projects
        }
      end

      def foundational_agents_data
        {
          foundational_agents_default_enabled: @group.foundational_agents_default_enabled.to_s,
          foundational_agents_statuses: ::Gitlab::Json.generate(@group.foundational_agents_statuses),
          show_foundational_agents_availability: show_foundational_agents_availability?.to_s,
          show_foundational_agents_per_agent_availability: show_foundational_agents_per_agent_availability?.to_s
        }
      end

      def foundational_flows_settings_data
        {
          duo_remote_flows_availability: @group.namespace_settings.duo_remote_flows_availability.to_s,
          duo_foundational_flows_availability: @group.namespace_settings.duo_foundational_flows_availability.to_s,
          available_foundational_flows: available_foundational_flows_json,
          selected_foundational_flow_references: selected_foundational_flows_json
        }
      end

      def available_foundational_flows_json
        return [].to_json unless @group.root?

        foundational_flows = ::Ai::Catalog::FoundationalFlow::ITEMS
          .select { |item| item[:foundational_flow_reference].present? }

        unless allow_beta_experimental_ai_features?
          foundational_flows.reject! { |item| item[:feature_maturity] && item[:feature_maturity] != 'ga' }
        end

        foundational_flows.map do |item|
          {
            name: item[:display_name],
            description: item[:description],
            reference: item[:foundational_flow_reference]
          }
        end.to_json
      end

      def selected_foundational_flows_json
        return [].to_json unless @group.root?

        @group.selected_foundational_flow_references.to_json
      end

      def cascading_tooltip_data(setting_key)
        cascading_namespace_settings_tooltip_data(setting_key, @group, method(:edit_group_path))[:tooltip_data]
      end

      def namespace_access_rules_data
        return {} if ::Feature.disabled?(:duo_access_through_namespaces, :instance)

        {
          namespace_access_rules: ::Gitlab::Json.dump(namespace_access_rules),
          parent_path: @group.full_path
        }
      end

      def namespace_access_rules
        rules = ::Ai::NamespaceFeatureAccessRule.by_root_namespace_group_by_through_namespace(@group)

        Ai::FeatureAccessRuleTransformer.transform(rules)
      end

      def show_foundational_agents_availability?
        saas? && @group.root?
      end

      def show_duo_agent_platform_enablement_setting?
        saas? && @group.root?
      end

      def show_foundational_agents_per_agent_availability?
        ::Feature.enabled?(:duo_foundational_agents_per_agent_availability, :instance) && saas? && @group.root?
      end

      def saas?
        ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end

      def allow_beta_experimental_ai_features?
        return @group.experiment_features_enabled if saas?

        ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
      end
    end
  end
end
