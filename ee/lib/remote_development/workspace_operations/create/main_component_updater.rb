# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class MainComponentUpdater
        include CreateConstants
        include Files

        # @param [Hash] context
        # @return [Hash]
        def self.update(context)
          context => {
            processed_devfile: Hash => processed_devfile,
            tools_dir: String => tools_dir,
            vscode_extension_marketplace_metadata: Hash => vscode_extension_marketplace_metadata
          }

          processed_devfile => {
            components: Array => components
          }

          # NOTE: We will always have exactly one main_component found, because we have already
          #       validated this in devfile_validator.rb
          main_component = components.find do |component|
            # NOTE: We can't use pattern matching here, because constants can't be used in pattern matching.
            #       Otherwise, we could do this all in a single pattern match.
            component.dig(:attributes, MAIN_COMPONENT_INDICATOR_ATTRIBUTE.to_sym)
          end

          main_component_container = main_component.fetch(:container)

          # TODO: When user-defined postStart commands are supported, add validation in previous devfile validation
          #       steps of the ".../workspace_operations/create" ROP chain.
          #       See: https://gitlab.com/gitlab-org/gitlab/-/issues/505988
          add_poststart_commands(
            processed_devfile: processed_devfile,
            main_component: main_component
          )

          update_env_vars(
            main_component_container: main_component_container,
            tools_dir: tools_dir,
            editor_port: WORKSPACE_EDITOR_PORT,
            ssh_port: WORKSPACE_SSH_PORT,
            enable_marketplace: vscode_extension_marketplace_metadata.fetch(:enabled)
          )

          update_endpoints(
            main_component_container: main_component_container,
            editor_port: WORKSPACE_EDITOR_PORT,
            ssh_port: WORKSPACE_SSH_PORT
          )

          override_command_and_args(
            main_component_container: main_component_container
          )

          context
        end

        # @param [Hash] main_component_container
        # @param [String] tools_dir
        # @param [Integer] editor_port
        # @param [Integer] ssh_port
        # @param [Boolean] enable_marketplace
        # @return [void]
        def self.update_env_vars(main_component_container:, tools_dir:, editor_port:, ssh_port:, enable_marketplace:)
          (main_component_container[:env] ||= []).append(
            {
              # NOTE: Only "TOOLS_DIR" env var is extracted to a constant, because it is the only one referenced
              #       in multiple different classes.
              name: TOOLS_DIR_ENV_VAR,
              value: tools_dir
            },
            {
              name: "GL_EDITOR_LOG_LEVEL",
              value: "info"
            },
            {
              name: "GL_EDITOR_PORT",
              value: editor_port.to_s
            },
            {
              name: "GL_SSH_PORT",
              value: ssh_port.to_s
            },
            {
              name: "GL_EDITOR_ENABLE_MARKETPLACE",
              value: enable_marketplace.to_s
            }
          )

          nil
        end

        # @param [Hash] main_component_container
        # @param [Integer] editor_port
        # @param [Integer] ssh_port
        # @return [void]
        def self.update_endpoints(main_component_container:, editor_port:, ssh_port:)
          (main_component_container[:endpoints] ||= []).append(
            {
              name: "editor-server",
              targetPort: editor_port,
              exposure: "public",
              secure: true,
              protocol: "https"
            },
            {
              name: "ssh-server",
              targetPort: ssh_port,
              exposure: "internal",
              secure: true
            }
          )

          nil
        end

        # @param [Hash] processed_devfile
        # @param [Hash] main_component
        # @return [void]
        def self.add_poststart_commands(processed_devfile:, main_component:)
          processed_devfile => {
            commands: Array => commands,
            events: {
              postStart: Array => poststart_events
            }
          }

          main_component => { name: String => main_component_name }

          # Add the start_sshd event
          start_sshd_command_id = "gl-start-sshd-command"
          commands << {
            id: start_sshd_command_id,
            exec: {
              commandLine: MAIN_COMPONENT_UPDATER_START_SSHD_SCRIPT,
              component: main_component_name
            }
          }
          poststart_events << start_sshd_command_id

          # Add the init_tools event
          init_tools_command_id = "gl-init-tools-command"
          commands << {
            id: init_tools_command_id,
            exec: {
              commandLine: MAIN_COMPONENT_UPDATER_INIT_TOOLS_SCRIPT,
              component: main_component_name
            }
          }
          poststart_events << init_tools_command_id

          # Add the sleep_until_container_is_running event
          sleep_until_container_is_running_command_id = "gl-sleep-until-container-is-running-command"
          sleep_until_container_is_running_script =
            format(
              MAIN_COMPONENT_UPDATER_SLEEP_UNTIL_CONTAINER_IS_RUNNING_SCRIPT,
              workspace_reconciled_actual_state_file_path: WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_PATH
            )

          commands << {
            id: sleep_until_container_is_running_command_id,
            exec: {
              commandLine: sleep_until_container_is_running_script,
              component: main_component_name
            }
          }
          poststart_events << sleep_until_container_is_running_command_id

          nil
        end

        # @param [Hash] main_component_container
        # @return [void]
        def self.override_command_and_args(main_component_container:)
          # This overrides the main container's command
          # Open issue to support both starting the editor and running the default command:
          # https://gitlab.com/gitlab-org/gitlab/-/issues/392853

          main_component_container[:command] = %w[/bin/sh -c]
          main_component_container[:args] = [MAIN_COMPONENT_UPDATER_CONTAINER_ARGS]

          nil
        end

        private_class_method :update_env_vars, :update_endpoints, :add_poststart_commands, :override_command_and_args
      end
    end
  end
end
