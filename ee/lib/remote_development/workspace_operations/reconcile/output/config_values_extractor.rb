# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Output
        class ConfigValuesExtractor
          include States

          # @param [RemoteDevelopment::Workspace] workspace
          # @return [Hash]
          def self.extract(workspace:)
            workspace_name = workspace.name
            workspaces_agent_config = workspace.workspaces_agent_config

            domain_template = "{{.port}}-#{workspace_name}.#{workspaces_agent_config.dns_zone}"

            max_resources_per_workspace =
              deep_sort_and_symbolize_hashes(workspaces_agent_config.max_resources_per_workspace)

            # NOTE: In order to prevent unwanted restarts of the workspace, we need to ensure that the hexdigest
            #       of the max_resources_per_workspace is backward compatible, and uses the same sorting as the
            #       legacy logic of existing running workspaces. This means that we only the top level keys are sorted,
            #       not the nested hashes. But everywhere else we will use the deeply sorted version. This workaround
            #       can be removed if we move all of this logic from workspace reconcile-time to create-time.
            #       Also note that the value has always been deep_symbolized before #to_s, so we preserve that as well.
            max_resources_per_workspace_sha256_with_legacy_sorting =
              OpenSSL::Digest::SHA256.hexdigest(
                workspaces_agent_config.max_resources_per_workspace.deep_symbolize_keys.sort.to_h.to_s
              )

            default_resources_per_workspace_container =
              deep_sort_and_symbolize_hashes(workspaces_agent_config.default_resources_per_workspace_container)

            extra_annotations = {
              "workspaces.gitlab.com/host-template": domain_template.to_s,
              "workspaces.gitlab.com/id": workspace.id.to_s,
              # NOTE: This annotation is added to cause the workspace to restart whenever the max resources change
              "workspaces.gitlab.com/max-resources-per-workspace-sha256":
                max_resources_per_workspace_sha256_with_legacy_sorting
            }
            agent_annotations = workspaces_agent_config.annotations
            common_annotations = agent_annotations.merge(extra_annotations)

            workspace_inventory_name = "#{workspace_name}-workspace-inventory"
            secrets_inventory_name = "#{workspace_name}-secrets-inventory"

            {
              # Please keep alphabetized
              allow_privilege_escalation: workspaces_agent_config.allow_privilege_escalation,
              common_annotations: deep_sort_and_symbolize_hashes(common_annotations),
              default_resources_per_workspace_container:
                default_resources_per_workspace_container,
              default_runtime_class: workspaces_agent_config.default_runtime_class,
              domain_template: domain_template,
              # NOTE: update env_secret_name to "#{workspace.name}-environment". This is to ensure naming consistency.
              # Changing it now would require migration from old config version to a new one.
              # Update this when a new desired config generator is created for some other reason.
              env_secret_name: "#{workspace_name}-env-var",
              file_secret_name: "#{workspace_name}-file",
              image_pull_secrets: deep_sort_and_symbolize_hashes(workspaces_agent_config.image_pull_secrets),
              gitlab_workspaces_proxy_namespace: workspaces_agent_config.gitlab_workspaces_proxy_namespace,
              labels:
                deep_sort_and_symbolize_hashes(
                  workspaces_agent_config.labels.merge({ "agent.gitlab.com/id": workspace.agent.id.to_s })
                ),
              network_policy_enabled: workspaces_agent_config.network_policy_enabled,
              network_policy_egress: deep_sort_and_symbolize_hashes(workspaces_agent_config.network_policy_egress),
              max_resources_per_workspace: max_resources_per_workspace,
              processed_devfile_yaml: workspace.processed_devfile,
              replicas: workspace.desired_state_running? ? 1 : 0,
              secrets_inventory_annotations:
                deep_sort_and_symbolize_hashes(
                  common_annotations.merge("config.k8s.io/owning-inventory": secrets_inventory_name)
                ),
              secrets_inventory_name: secrets_inventory_name,
              use_kubernetes_user_namespaces: workspaces_agent_config.use_kubernetes_user_namespaces,
              workspace_inventory_annotations:
                deep_sort_and_symbolize_hashes(
                  common_annotations.merge("config.k8s.io/owning-inventory": workspace_inventory_name)
                ),
              workspace_inventory_name: workspace_inventory_name
            }
          end

          # @param [Array, Hash] collection
          # @return [Array, Hash]
          def self.deep_sort_and_symbolize_hashes(collection)
            collection_to_return = Gitlab::Utils.deep_sort_hashes(collection)

            # NOTE: deep_symbolize_keys! is not available on Array, so we wrap the collection in a
            #       Hash in case it is an Array.
            { to_symbolize: collection_to_return }.deep_symbolize_keys!
            collection_to_return
          end

          private_class_method :deep_sort_and_symbolize_hashes
        end
      end
    end
  end
end
