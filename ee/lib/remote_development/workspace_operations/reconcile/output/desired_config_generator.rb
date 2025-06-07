# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Output
        class DesiredConfigGenerator
          include ReconcileConstants

          # @param [RemoteDevelopment::Workspace] workspace
          # @param [Boolean] include_all_resources
          # @param [RemoteDevelopment::Logger] logger
          # @return [Array<Hash>]
          def self.generate_desired_config(workspace:, include_all_resources:, logger:)
            config_values_extractor_result = ConfigValuesExtractor.extract(workspace: workspace)
            config_values_extractor_result => {
              allow_privilege_escalation: TrueClass | FalseClass => allow_privilege_escalation,
              common_annotations: Hash => common_annotations,
              default_resources_per_workspace_container: Hash => default_resources_per_workspace_container,
              default_runtime_class: String => default_runtime_class,
              domain_template: String => domain_template,
              env_secret_name: String => env_secret_name,
              file_secret_name: String => file_secret_name,
              gitlab_workspaces_proxy_namespace: String => gitlab_workspaces_proxy_namespace,
              image_pull_secrets: Array => image_pull_secrets,
              labels: Hash => labels,
              max_resources_per_workspace: Hash => max_resources_per_workspace,
              network_policy_enabled: TrueClass | FalseClass => network_policy_enabled,
              network_policy_egress: Array => network_policy_egress,
              processed_devfile_yaml: String => processed_devfile_yaml,
              replicas: Integer => replicas,
              scripts_configmap_name: scripts_configmap_name,
              secrets_inventory_annotations: Hash => secrets_inventory_annotations,
              secrets_inventory_name: String => secrets_inventory_name,
              shared_namespace: String => shared_namespace,
              use_kubernetes_user_namespaces: TrueClass | FalseClass => use_kubernetes_user_namespaces,
              workspace_inventory_annotations: Hash => workspace_inventory_annotations,
              workspace_inventory_name: String => workspace_inventory_name,
            }

            desired_config = []

            CreateDesiredConfigGenerator.append_inventory_config_map(
              desired_config: desired_config,
              name: workspace_inventory_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: common_annotations
            )

            if workspace.desired_state_terminated?
              CreateDesiredConfigGenerator.append_inventory_config_map(
                desired_config: desired_config,
                name: secrets_inventory_name,
                namespace: workspace.namespace,
                labels: labels,
                annotations: common_annotations
              )

              return desired_config
            end

            devfile_parser_params = {
              allow_privilege_escalation: allow_privilege_escalation,
              annotations: workspace_inventory_annotations,
              default_resources_per_workspace_container: default_resources_per_workspace_container,
              default_runtime_class: default_runtime_class,
              domain_template: domain_template,
              env_secret_names: [env_secret_name],
              file_secret_names: [file_secret_name],
              labels: labels,
              name: workspace.name,
              namespace: workspace.namespace,
              replicas: replicas,
              service_account_name: workspace.name,
              use_kubernetes_user_namespaces: use_kubernetes_user_namespaces
            }

            resources_from_devfile_parser = DevfileParser.get_all(
              processed_devfile_yaml: processed_devfile_yaml,
              params: devfile_parser_params,
              logger: logger
            )

            # If we got no resources back from the devfile parser, this indicates some error was encountered in parsing
            # the processed_devfile. So we return an empty array which will result in no updates being applied by the
            # agent. We should not continue on and try to add anything else to the resources, as this would result
            # in an invalid configuration being applied to the cluster.
            return [] if resources_from_devfile_parser.empty?

            desired_config.append(*resources_from_devfile_parser)

            CreateDesiredConfigGenerator.append_image_pull_secrets_service_account(
              desired_config: desired_config,
              name: workspace.name,
              namespace: workspace.namespace,
              image_pull_secrets: image_pull_secrets,
              labels: labels,
              annotations: workspace_inventory_annotations
            )

            CreateDesiredConfigGenerator.append_network_policy(
              desired_config: desired_config,
              name: workspace.name,
              namespace: workspace.namespace,
              gitlab_workspaces_proxy_namespace: gitlab_workspaces_proxy_namespace,
              network_policy_enabled: network_policy_enabled,
              network_policy_egress: network_policy_egress,
              labels: labels,
              annotations: workspace_inventory_annotations
            )

            CreateDesiredConfigGenerator.append_scripts_resources(
              desired_config: desired_config,
              processed_devfile_yaml: processed_devfile_yaml,
              name: scripts_configmap_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: workspace_inventory_annotations
            )

            return desired_config unless include_all_resources

            CreateDesiredConfigGenerator.append_inventory_config_map(
              desired_config: desired_config,
              name: secrets_inventory_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: common_annotations
            )

            CreateDesiredConfigGenerator.append_resource_quota(
              desired_config: desired_config,
              name: workspace.name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: workspace_inventory_annotations,
              max_resources_per_workspace: max_resources_per_workspace,
              shared_namespace: shared_namespace
            )

            CreateDesiredConfigGenerator.append_secret(
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

            CreateDesiredConfigGenerator.append_secret(
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

            append_secret_data(
              desired_config: desired_config,
              secret_name: file_secret_name,
              data: { WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_NAME.to_sym => workspace.actual_state }
            )

            desired_config
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

          private_class_method :append_secret_data_from_variables, :append_secret_data
        end
      end
    end
  end
end
