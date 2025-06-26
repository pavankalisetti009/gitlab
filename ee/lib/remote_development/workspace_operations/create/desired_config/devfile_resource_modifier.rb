# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      module DesiredConfig
        class DevfileResourceModifier
          include RemoteDevelopment::WorkspaceOperations::Create::CreateConstants

          def self.modify(context)
            context => {
              workspace_name: String => workspace_name,
              desired_config_array: Array => desired_config_array,
              use_kubernetes_user_namespaces: TrueClass | FalseClass => use_kubernetes_user_namespaces,
              default_runtime_class: String => default_runtime_class,
              allow_privilege_escalation: TrueClass | FalseClass => allow_privilege_escalation,
              default_resources_per_workspace_container: Hash => default_resources_per_workspace_container,
              env_secret_name: String => env_secret_name,
              file_secret_name: String => file_secret_name,
            }

            desired_config_array = set_host_users(
              desired_config_array: desired_config_array,
              use_kubernetes_user_namespaces: use_kubernetes_user_namespaces
            )
            desired_config_array = set_runtime_class(
              desired_config_array: desired_config_array,
              runtime_class_name: default_runtime_class
            )
            desired_config_array = set_security_context(
              desired_config_array: desired_config_array,
              allow_privilege_escalation: allow_privilege_escalation
            )
            desired_config_array = patch_default_resources(
              desired_config_array: desired_config_array,
              default_resources_per_workspace_container:
                default_resources_per_workspace_container
            )
            desired_config_array = inject_secrets(
              desired_config_array: desired_config_array,
              env_secret_name: env_secret_name,
              file_secret_name: file_secret_name
            )

            set_service_account(
              desired_config_array: desired_config_array,
              service_account_name: workspace_name
            )

            context.merge({ desired_config_array: desired_config_array })
          end

          def self.set_host_users(desired_config_array:, use_kubernetes_user_namespaces:)
            # NOTE: Not setting the use_kubernetes_user_namespaces always since setting it now would require migration
            # from old config version to a new one. Set this field always
            # when a new devfile parser is created for some other reason.
            return desired_config_array unless use_kubernetes_user_namespaces

            desired_config_array.each do |workspace_resource|
              next unless workspace_resource[:kind] == 'Deployment'

              workspace_resource[:spec][:template][:spec][:hostUsers] = use_kubernetes_user_namespaces
            end
            desired_config_array
          end

          # @param [Array<Hash>] desired_config_array
          # @param [String] runtime_class_name
          # @return [Array<Hash>]
          def self.set_runtime_class(desired_config_array:, runtime_class_name:)
            # NOTE: Not setting the runtime_class_name always since changing it now would require migration
            # from old config version to a new one. Update this field to `runtime_class_name.presence`
            # when a new devfile parser is created for some other reason.
            return desired_config_array if runtime_class_name.empty?

            desired_config_array.each do |workspace_resource|
              next unless workspace_resource[:kind] == 'Deployment'

              workspace_resource[:spec][:template][:spec][:runtimeClassName] = runtime_class_name
            end
            desired_config_array
          end

          # Devfile library allows specifying the security context of pods/containers as mentioned in
          # https://github.com/devfile/api/issues/920 through `pod-overrides` and `container-overrides` attributes.
          # However, https://github.com/devfile/library/pull/158 which is implementing this feature,
          # is not part of v2.2.0 which is the latest release of the devfile which is being used in the devfile-gem.
          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409189
          #       Once devfile library releases a new version, update the devfile-gem and move
          #       the logic of setting the security context as part of workspace creation.

          # @param [Array<Hash>] desired_config_array
          # @param [Boolean] allow_privilege_escalation
          # @param [Boolean] use_kubernetes_user_namespaces
          # @return [Array<Hash>]
          def self.set_security_context(
            desired_config_array:,
            allow_privilege_escalation:
          )
            desired_config_array.each do |workspace_resource|
              next unless workspace_resource[:kind] == 'Deployment'

              pod_security_context = {
                runAsNonRoot: true,
                runAsUser: RUN_AS_USER,
                fsGroup: 0,
                fsGroupChangePolicy: 'OnRootMismatch'
              }
              container_security_context = {
                allowPrivilegeEscalation: allow_privilege_escalation,
                privileged: false,
                runAsNonRoot: true,
                runAsUser: RUN_AS_USER
              }

              pod_spec = workspace_resource[:spec][:template][:spec]
              # Explicitly set security context for the pod
              pod_spec[:securityContext] = pod_security_context
              # Explicitly set security context for all containers
              pod_spec[:containers].each do |container|
                container[:securityContext] = container_security_context
              end
              # Explicitly set security context for all init containers
              pod_spec[:initContainers].each do |init_container|
                init_container[:securityContext] = container_security_context
              end
            end
            desired_config_array
          end

          # @param [Array<Hash>] desired_config_array
          # @param [Hash] default_resources_per_workspace_container
          # @return [Array<Hash>]
          def self.patch_default_resources(desired_config_array:, default_resources_per_workspace_container:)
            desired_config_array.each do |workspace_resource|
              next unless workspace_resource.fetch(:kind) == 'Deployment'

              pod_spec = workspace_resource.fetch(:spec).fetch(:template).fetch(:spec)

              container_types = [:initContainers, :containers]
              container_types.each do |container_type|
                # the purpose of this deep_merge is to ensure
                # the values from the devfile override any defaults defined at the agent
                pod_spec.fetch(container_type).each do |container|
                  container
                    .fetch(:resources, {})
                    .deep_merge!(default_resources_per_workspace_container) { |_, val, _| val }
                end
              end
            end
            desired_config_array
          end

          # @param [Array<Hash>] desired_config_array
          # @param [String] env_secret_name
          # @param [String] file_secret_name
          # @return [Array<Hash>]
          def self.inject_secrets(desired_config_array:, env_secret_name:, file_secret_name:)
            desired_config_array.each do |workspace_resource|
              next unless workspace_resource.fetch(:kind) == 'Deployment'

              volume = {
                name: VARIABLES_VOLUME_NAME,
                projected: {
                  defaultMode: VARIABLES_VOLUME_DEFAULT_MODE,
                  sources: [{ secret: { name: file_secret_name } }]
                }
              }

              volume_mount = {
                name: VARIABLES_VOLUME_NAME,
                mountPath: VARIABLES_VOLUME_PATH
              }

              env_from = [{ secretRef: { name: env_secret_name } }]

              pod_spec = workspace_resource.fetch(:spec).fetch(:template).fetch(:spec)
              pod_spec.fetch(:volumes) << volume unless file_secret_name.empty?

              pod_spec.fetch(:initContainers).each do |init_container|
                init_container.fetch(:volumeMounts) << volume_mount unless file_secret_name.empty?
                init_container[:envFrom] = env_from unless env_secret_name.empty?
              end

              pod_spec.fetch(:containers).each do |container|
                container.fetch(:volumeMounts) << volume_mount unless file_secret_name.empty?
                container[:envFrom] = env_from unless env_secret_name.empty?
              end
            end
            desired_config_array
          end

          # @param [Array<Hash>] desired_config_array
          # @param [String] service_account_name
          # @return [Array<Hash>]
          def self.set_service_account(desired_config_array:, service_account_name:)
            desired_config_array.each do |workspace_resource|
              next unless workspace_resource.fetch(:kind) == 'Deployment'

              workspace_resource[:spec][:template][:spec][:serviceAccountName] = service_account_name
            end
            desired_config_array
          end

          private_class_method :set_host_users,
            :set_runtime_class,
            :set_security_context,
            :patch_default_resources,
            :inject_secrets,
            :set_service_account
        end
      end
    end
  end
end
