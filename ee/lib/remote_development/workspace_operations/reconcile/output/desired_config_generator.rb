# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Output
        class DesiredConfigGenerator
          include States

          # @param [RemoteDevelopment::Workspace] workspace
          # @param [Boolean] include_all_resources
          # @param [RemoteDevelopment::Logger] logger
          # @return [Array<Hash>]
          def self.generate_desired_config(workspace:, include_all_resources:, logger:)
            # NOTE: update env_secret_name to "#{workspace.name}-environment". This is to ensure naming consistency.
            # Changing it now would require migration from old config version to a new one.
            # Update this when a new desired config generator is created for some other reason.
            env_secret_name = "#{workspace.name}-env-var"
            file_secret_name = "#{workspace.name}-file"
            workspaces_agent_config = workspace.workspaces_agent_config

            max_resources_per_workspace = workspaces_agent_config.max_resources_per_workspace.deep_symbolize_keys

            agent_annotations = workspaces_agent_config.annotations
            domain_template = "{{.port}}-#{workspace.name}.#{workspaces_agent_config.dns_zone}"
            common_annotations = get_common_annotations(
              agent_annotations: agent_annotations,
              domain_template: domain_template,
              workspace_id: workspace.id,
              max_resources_per_workspace: max_resources_per_workspace
            )

            workspace_inventory_name = "#{workspace.name}-workspace-inventory"
            workspace_inventory_annotations =
              common_annotations.merge("config.k8s.io/owning-inventory": workspace_inventory_name)

            labels = workspaces_agent_config.labels.merge({ "agent.gitlab.com/id": workspace.agent.id.to_s })

            resources_from_devfile_parser = DevfileParser.get_all(
              processed_devfile: workspace.processed_devfile,
              params: get_devfile_parser_params(
                workspace: workspace,
                workspaces_agent_config: workspaces_agent_config,
                domain_template: domain_template,
                labels: labels,
                annotations: workspace_inventory_annotations,
                env_secret_name: env_secret_name,
                file_secret_name: file_secret_name
              ),
              logger: logger
            )

            # If we got no resources back from the devfile parser, this indicates some error was encountered in parsing
            # the processed_devfile. So we return an empty array which will result in no updates being applied by the
            # agent. We should not continue on and try to add anything else to the resources, as this would result
            # in an invalid configuration being applied to the cluster.
            return [] if resources_from_devfile_parser.empty?

            desired_config = []

            append_inventory_config_map(
              desired_config: desired_config,
              name: workspace_inventory_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: workspace_inventory_annotations
            )

            desired_config.append(*resources_from_devfile_parser)

            append_image_pull_secrets_service_account(
              desired_config: desired_config,
              name: workspace.name,
              namespace: workspace.namespace,
              image_pull_secrets: workspaces_agent_config.image_pull_secrets,
              labels: labels,
              annotations: workspace_inventory_annotations
            )

            append_network_policy(
              desired_config: desired_config,
              workspaces_agent_config: workspaces_agent_config,
              name: workspace.name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: workspace_inventory_annotations
            )

            secrets_inventory_name = "#{workspace.name}-secrets-inventory"
            secrets_inventory_annotations =
              common_annotations.merge("config.k8s.io/owning-inventory": secrets_inventory_name)

            append_inventory_config_map(
              desired_config: desired_config,
              name: secrets_inventory_name,
              labels: labels,
              annotations: workspace_inventory_annotations,
              namespace: workspace.namespace
            )

            # NOTE: We will perform append_secret here in order to complete
            #       https://gitlab.com/gitlab-org/gitlab/-/merge_requests/182392

            return desired_config unless include_all_resources

            append_resource_quota(
              desired_config: desired_config,
              name: workspace.name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: workspace_inventory_annotations,
              max_resources_per_workspace: max_resources_per_workspace
            )

            append_secret(
              desired_config: desired_config,
              name: env_secret_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: secrets_inventory_annotations
            )

            append_secret_data_from_variables(
              desired_config: desired_config,
              secret_name: env_secret_name,
              variables: workspace.workspace_variables.with_variable_type_environment
            )

            append_secret(
              desired_config: desired_config,
              name: file_secret_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: secrets_inventory_annotations
            )

            append_secret_data_from_variables(
              desired_config: desired_config,
              secret_name: file_secret_name,
              variables: workspace.workspace_variables.with_variable_type_file
            )

            desired_config
          end

          # @param [RemoteDevelopment::Workspace] workspace
          # @param [RemoteDevelopment::WorkspacesAgentConfig] workspaces_agent_config
          # @param [String] domain_template
          # @param [Hash<String, String>] labels
          # @param [Hash<String, String>] annotations
          # @param [String] env_secret_name
          # @param [String] file_secret_name
          # @return [Hash]
          def self.get_devfile_parser_params(
            workspace:,
            workspaces_agent_config:,
            domain_template:,
            labels:,
            annotations:,
            env_secret_name:,
            file_secret_name:
          )
            {
              name: workspace.name,
              namespace: workspace.namespace,
              replicas: get_workspace_replicas(desired_state: workspace.desired_state),
              domain_template: domain_template,
              labels: labels,
              annotations: annotations,
              env_secret_names: [env_secret_name],
              file_secret_names: [file_secret_name],
              service_account_name: workspace.name,
              default_resources_per_workspace_container:
                workspaces_agent_config
                  .default_resources_per_workspace_container
                  .deep_symbolize_keys,
              allow_privilege_escalation: workspaces_agent_config.allow_privilege_escalation,
              use_kubernetes_user_namespaces: workspaces_agent_config.use_kubernetes_user_namespaces,
              default_runtime_class: workspaces_agent_config.default_runtime_class
            }
          end

          # @param [String] desired_state
          # @return [Integer]
          def self.get_workspace_replicas(desired_state:)
            return 1 if [
              CREATION_REQUESTED,
              RUNNING
            ].include?(desired_state)

            0
          end

          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash<String, String>] labels
          # @param [Hash<String, String>] annotations
          # @return [void]
          def self.append_inventory_config_map(
            desired_config:,
            name:,
            namespace:,
            labels:,
            annotations:
          )
            extra_labels = { "cli-utils.sigs.k8s.io/inventory-id": name }

            config_map = {
              kind: "ConfigMap",
              apiVersion: "v1",
              metadata: {
                name: name,
                namespace: namespace,
                labels: labels.merge(extra_labels),
                annotations: annotations
              }
            }

            desired_config.append(config_map)

            nil
          end

          # @param [Hash<String, String>] agent_annotations
          # @param [String] domain_template
          # @param [Integer] workspace_id
          # @param [Hash] max_resources_per_workspace
          # @return [Hash]
          def self.get_common_annotations(
            agent_annotations:,
            domain_template:,
            workspace_id:,
            max_resources_per_workspace:
          )
            extra_annotations = {
              "workspaces.gitlab.com/host-template": domain_template.to_s,
              "workspaces.gitlab.com/id": workspace_id.to_s,
              # NOTE: This annotation is added to cause the workspace to restart whenever the max resources change
              "workspaces.gitlab.com/max-resources-per-workspace-sha256":
                OpenSSL::Digest::SHA256.hexdigest(max_resources_per_workspace.sort.to_h.to_s)
            }
            agent_annotations.merge(extra_annotations)
          end

          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @return [void]
          def self.append_secret(desired_config:, name:, namespace:, labels:, annotations:)
            secret = {
              kind: "Secret",
              apiVersion: "v1",
              metadata: {
                name: name,
                namespace: namespace,
                labels: labels,
                annotations: annotations
              },
              data: {}
            }

            desired_config.append(secret)

            nil
          end

          # @param [Array] desired_config
          # @param [String] secret_name
          # @param [ActiveRecord::Relation<RemoteDevelopment::WorkspaceVariable>] variables
          # @return [void]
          def self.append_secret_data_from_variables(desired_config:, secret_name:, variables:)
            data = variables.each_with_object({}) do |workspace_variable, hash|
              hash[workspace_variable.key.to_sym] = workspace_variable.value
            end

            append_secret_data(
              desired_config: desired_config,
              secret_name: secret_name,
              data: data
            )

            nil
          end

          # @param [Array] desired_config
          # @param [String] secret_name
          # @param [Hash] data
          # @return [void]
          # noinspection RubyUnusedLocalVariable -- Rubymine doesn't recognize '^' to use a variable in pattern-matching
          def self.append_secret_data(desired_config:, secret_name:, data:)
            desired_config => [
              *_,
              {
                metadata: {
                  name: ^secret_name
                },
                data: secret_data
              },
              *_
            ]

            transformed_data = data.transform_values { |value| Base64.strict_encode64(value) }

            secret_data.merge!(transformed_data)

            nil
          end

          # @param [Array] desired_config
          # @param [RemoteDevelopment::WorkspacesAgentConfig] workspaces_agent_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @return [void]
          def self.append_network_policy(
            desired_config:,
            workspaces_agent_config:,
            name:,
            namespace:,
            labels:,
            annotations:
          )
            return unless workspaces_agent_config.network_policy_enabled

            gitlab_workspaces_proxy_namespace = workspaces_agent_config.gitlab_workspaces_proxy_namespace
            egress_ip_rules = workspaces_agent_config.network_policy_egress

            policy_types = %w[Ingress Egress]

            proxy_namespace_selector = {
              matchLabels: {
                "kubernetes.io/metadata.name": gitlab_workspaces_proxy_namespace
              }
            }
            proxy_pod_selector = {
              matchLabels: {
                "app.kubernetes.io/name": "gitlab-workspaces-proxy"
              }
            }
            ingress = [{ from: [{ namespaceSelector: proxy_namespace_selector, podSelector: proxy_pod_selector }] }]

            kube_system_namespace_selector = {
              matchLabels: {
                "kubernetes.io/metadata.name": "kube-system"
              }
            }
            egress = [
              {
                ports: [{ port: 53, protocol: "TCP" }, { port: 53, protocol: "UDP" }],
                to: [{ namespaceSelector: kube_system_namespace_selector }]
              }
            ]
            egress_ip_rules.each do |egress_rule|
              symbolized_egress_rule = egress_rule.deep_symbolize_keys
              egress.append(
                { to: [{ ipBlock: { cidr: symbolized_egress_rule[:allow], except: symbolized_egress_rule[:except] } }] }
              )
            end

            network_policy = {
              apiVersion: "networking.k8s.io/v1",
              kind: "NetworkPolicy",
              metadata: {
                annotations: annotations,
                labels: labels,
                name: name,
                namespace: namespace
              },
              spec: {
                egress: egress,
                ingress: ingress,
                podSelector: {},
                policyTypes: policy_types
              }
            }

            desired_config.append(network_policy)

            nil
          end

          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Hash] max_resources_per_workspace
          # @return [void]
          def self.append_resource_quota(
            desired_config:,
            name:,
            namespace:,
            labels:,
            annotations:,
            max_resources_per_workspace:
          )
            return unless max_resources_per_workspace.present?

            max_resources_per_workspace => {
              limits: {
                cpu: limits_cpu,
                memory: limits_memory
              },
              requests: {
                cpu: requests_cpu,
                memory: requests_memory
              }
            }

            resource_quota = {
              apiVersion: "v1",
              kind: "ResourceQuota",
              metadata: {
                annotations: annotations,
                labels: labels,
                name: name,
                namespace: namespace
              },
              spec: {
                hard: {
                  "limits.cpu": limits_cpu,
                  "limits.memory": limits_memory,
                  "requests.cpu": requests_cpu,
                  "requests.memory": requests_memory
                }
              }
            }

            desired_config.append(resource_quota)

            nil
          end

          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Array] image_pull_secrets
          # @return [void]
          def self.append_image_pull_secrets_service_account(
            desired_config:,
            name:,
            namespace:,
            labels:,
            annotations:,
            image_pull_secrets:
          )
            image_pull_secrets_names = image_pull_secrets.map { |secret| { name: secret.fetch("name") } }

            workspace_service_account_definition = {
              apiVersion: "v1",
              kind: "ServiceAccount",
              metadata: {
                name: name,
                namespace: namespace,
                annotations: annotations,
                labels: labels
              },
              automountServiceAccountToken: false,
              imagePullSecrets: image_pull_secrets_names
            }

            desired_config.append(workspace_service_account_definition)

            nil
          end

          private_class_method :get_devfile_parser_params, :get_workspace_replicas, :append_inventory_config_map,
            :get_common_annotations, :append_secret, :append_secret_data_from_variables, :append_secret_data,
            :append_network_policy, :append_resource_quota, :append_image_pull_secrets_service_account
        end
      end
    end
  end
end
