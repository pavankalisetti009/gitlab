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

        model_errors = nil
        workspaces_update_all_error = nil

        ApplicationRecord.transaction do
          # First, create or update the workspaces_agent_config record

          unless workspaces_agent_config.save
            model_errors = workspaces_agent_config.errors
            raise ActiveRecord::Rollback
          end

          # Then, update the associated workspaces even if there were no material changes to the agent config

          workspaces_update_fields = { force_include_all_resources: true }

          # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
          if workspaces_agent_config.dns_zone_previously_was
            workspaces_update_fields[:dns_zone] = workspaces_agent_config.dns_zone
          end

          begin
            workspaces_agent_config.workspaces.desired_state_not_terminated.touch_all
            workspaces_agent_config.workspaces.desired_state_not_terminated.update_all(workspaces_update_fields)
          rescue ActiveRecord::ActiveRecordError => e
            workspaces_update_all_error = "Error updating associated workspaces with update_all: #{e.message}"
            raise ActiveRecord::Rollback
          end
        end

        return Gitlab::Fp::Result.err(AgentConfigUpdateFailed.new({ errors: model_errors })) if model_errors.present?

        if workspaces_update_all_error
          return Gitlab::Fp::Result.err(AgentConfigUpdateFailed.new({ details: workspaces_update_all_error }))
        end

        Gitlab::Fp::Result.ok(
          AgentConfigUpdateSuccessful.new({ workspaces_agent_config: workspaces_agent_config })
        )
      end

      # @param [Clusters::Agent] agent
      # @param [Hash] config_from_agent_config_file
      # @return [RemoteDevelopment::WorkspacesAgentConfig]
      def self.find_or_initialize_workspaces_agent_config(agent:, config_from_agent_config_file:)
        model_instance = WorkspacesAgentConfig.find_or_initialize_by(agent: agent) # rubocop:todo CodeReuse/ActiveRecord -- Use a finder class here

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
            :workspaces_quota
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

        model_instance
      end

      private_class_method :find_or_initialize_workspaces_agent_config
    end
  end
end
