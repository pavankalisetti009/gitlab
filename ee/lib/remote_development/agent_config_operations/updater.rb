# frozen_string_literal: true

module RemoteDevelopment
  module AgentConfigOperations
    class Updater
      include Messages

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.update(context)
        context => { agent: Clusters::Agent => agent, config: Hash => config }
        config_from_agent_config_file = config[:remote_development]

        unless config_from_agent_config_file
          return Gitlab::Fp::Result.ok(
            AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound.new({ skipped_reason: :no_config_file_entry_found })
          )
        end

        workspaces_agent_config = find_or_initialize_workspaces_agent_config(
          agent: agent,
          config_from_agent_config_file: config_from_agent_config_file
        )

        model_errors = workspaces_agent_config.errors unless workspaces_agent_config.save

        return Gitlab::Fp::Result.err(AgentConfigUpdateFailed.new({ errors: model_errors })) if model_errors.present?

        Gitlab::Fp::Result.ok(
          AgentConfigUpdateSuccessful.new({ workspaces_agent_config: workspaces_agent_config })
        )
      end

      # @param [Clusters::Agent] agent
      # @param [Hash] config_from_agent_config_file
      # @return [RemoteDevelopment::WorkspacesAgentConfig]
      # rubocop:disable Metrics/AbcSize -- This is being resolved by refactoring in https://gitlab.com/gitlab-org/gitlab/-/merge_requests/166065
      def self.find_or_initialize_workspaces_agent_config(agent:, config_from_agent_config_file:)
        model_instance = WorkspacesAgentConfig.find_or_initialize_by(agent: agent) # rubocop:disable CodeReuse/ActiveRecord -- We don't want to use a finder, we want to use find_or_initialize_by because it's more concise

        normalized_config_from_file = config_from_agent_config_file.dup.to_h.transform_keys(&:to_sym)

        # NOTE: In the agent config file, the `namespace` is nested under `gitlab_workspaces_proxy`, but in the database
        #       it is a single `gitlab_workspaces_proxy_namespace`, not a jsonb field for `gitlab_workspaces_proxy`.
        #       So, in order to do the `merge` below of config_from_agent_config_file into agent_config_settings,
        #       we will make the config_from_agent_config_file match the single field name.
        proxy_namespace = normalized_config_from_file.dig(:gitlab_workspaces_proxy, :namespace)
        normalized_config_from_file[:gitlab_workspaces_proxy_namespace] = proxy_namespace if proxy_namespace
        #       Same for `network_policy_enabled` and `network_policy_egress` db fields - rename them from the
        #       network_policy field in the config_from_agent_config_file spec
        network_policy_enabled = normalized_config_from_file.dig(:network_policy, :enabled)
        normalized_config_from_file[:network_policy_enabled] = network_policy_enabled if network_policy_enabled
        network_policy_egress = normalized_config_from_file.dig(:network_policy, :egress)
        normalized_config_from_file[:network_policy_egress] = network_policy_egress if network_policy_egress

        # NOTE: We rely on the settings module to fetch the defaults of all values except `enabled` in the
        #       agent config file. This is temporary pending completion of the settings module/UI which will
        #       remove the dependence on the agent config file for these values.

        agent_config_settings = Settings.get(
          [
            :default_max_hours_before_termination,
            :default_resources_per_workspace_container,
            :gitlab_workspaces_proxy_namespace,
            :max_hours_before_termination_limit,
            :max_resources_per_workspace,
            :network_policy_egress,
            :network_policy_enabled,
            :workspaces_per_user_quota,
            :workspaces_quota,
            :allow_privilege_escalation,
            :use_kubernetes_user_namespaces,
            :default_runtime_class,
            :annotations,
            :labels,
            :image_pull_secrets
          ]
        )
        agent_config_values = agent_config_settings.merge(normalized_config_from_file)

        # NOTE: `enabled` is the one field we can't easily move into the Settings module, so its default
        #       remains hardcoded here.
        model_instance.enabled = agent_config_values.fetch(:enabled, false)

        model_instance.project_id = agent.project_id
        model_instance.workspaces_quota = agent_config_values.fetch(:workspaces_quota)
        model_instance.workspaces_per_user_quota = agent_config_values.fetch(:workspaces_per_user_quota)
        model_instance.dns_zone = agent_config_values[:dns_zone]
        model_instance.network_policy_enabled = agent_config_values.fetch(:network_policy_enabled)
        model_instance.network_policy_egress = agent_config_values.fetch(:network_policy_egress)
        model_instance.gitlab_workspaces_proxy_namespace = agent_config_values.fetch(:gitlab_workspaces_proxy_namespace)
        model_instance.default_resources_per_workspace_container =
          agent_config_values.fetch(:default_resources_per_workspace_container)
        model_instance.max_resources_per_workspace = agent_config_values.fetch(:max_resources_per_workspace)
        model_instance.default_max_hours_before_termination =
          agent_config_values.fetch(:default_max_hours_before_termination)
        model_instance.max_hours_before_termination_limit =
          agent_config_values.fetch(:max_hours_before_termination_limit)
        model_instance.allow_privilege_escalation = agent_config_values.fetch(:allow_privilege_escalation)
        model_instance.use_kubernetes_user_namespaces = agent_config_values.fetch(:use_kubernetes_user_namespaces)
        model_instance.default_runtime_class = agent_config_values.fetch(:default_runtime_class)
        model_instance.annotations = agent_config_values.fetch(:annotations)
        model_instance.labels = agent_config_values.fetch(:labels)
        model_instance.image_pull_secrets = agent_config_values.fetch(:image_pull_secrets)

        model_instance
      end
      # rubocop:enable Metrics/AbcSize

      private_class_method :find_or_initialize_workspaces_agent_config
    end
  end
end
