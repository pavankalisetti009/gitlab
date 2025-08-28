# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Output
        class OldScriptsConfigmapAppender
          include Create::CreateConstants
          include WorkspaceOperationsConstants
          extend Create::DesiredConfig::PoststartCommandsHelper

          # rubocop:disable Metrics/ParameterLists -- all arguments needed
          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [String] project_path
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Array<Hash>] devfile_commands
          # @param [Hash] devfile_events
          # @param [Hash] processed_devfile
          # @return [void]
          def self.append(
            desired_config:,
            name:,
            namespace:,
            project_path:,
            labels:,
            annotations:,
            devfile_commands:,
            devfile_events:,
            processed_devfile:
          )
            configmap_data = {}

            configmap =
              {
                kind: "ConfigMap",
                apiVersion: "v1",
                metadata: {
                  name: name,
                  namespace: namespace,
                  labels: labels,
                  annotations: annotations
                },
                data: configmap_data
              }

            add_devfile_command_scripts_to_configmap_data(
              configmap_data: configmap_data,
              devfile_commands: devfile_commands,
              devfile_events: devfile_events
            )

            add_run_poststart_commands_script_to_configmap_data(
              configmap_data: configmap_data,
              devfile_commands: devfile_commands,
              devfile_events: devfile_events,
              project_path: project_path,
              processed_devfile: processed_devfile
            )

            # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
            configmap[:data] = Gitlab::Utils.deep_sort_hashes(configmap_data).to_h

            desired_config.append(configmap)

            nil
          end
          # rubocop:enable Metrics/ParameterLists

          # @param [Hash] configmap_data
          # @param [Array<Hash>] devfile_commands
          # @param [Hash] devfile_events
          # @return [void]
          def self.add_devfile_command_scripts_to_configmap_data(configmap_data:, devfile_commands:, devfile_events:)
            devfile_events => { postStart: Array => poststart_command_ids }

            poststart_command_ids.each do |poststart_command_id|
              command = devfile_commands.find { |command| command.fetch(:id) == poststart_command_id }
              command => {
                exec: {
                  commandLine: String => command_line
                }
              }

              configmap_data[poststart_command_id.to_sym] = command_line
            end

            nil
          end

          # @param [Hash] configmap_data
          # @param [Hash] processed_devfile
          # @param [Array<Hash>] devfile_commands
          # @param [Hash] devfile_events
          # @param [String] project_path
          # @return [void]
          def self.add_run_poststart_commands_script_to_configmap_data(
            configmap_data:,
            processed_devfile:,
            devfile_commands:,
            devfile_events:,
            project_path:
          )
            devfile_events => { postStart: Array => poststart_command_ids }

            internal_blocking_command_label_present = devfile_commands.find do |command|
              command.dig(:exec, :label) == INTERNAL_BLOCKING_COMMAND_LABEL
            end

            main_component_name = extract_main_component_name(
              processed_devfile: processed_devfile
            )

            unless internal_blocking_command_label_present
              # SAST IGNORE: String interpolation in shell context is safe here
              # The interpolated method call returns validated script content
              # Future SAST alerts on this heredoc can be safely ignored
              # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/547719
              configmap_data[LEGACY_RUN_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym] =
                <<~SH.chomp
                  #!/bin/sh
                  #{get_poststart_command_script_content(poststart_command_ids: poststart_command_ids, devfile_commands: devfile_commands, project_path: project_path, main_component_name: main_component_name, is_legacy_poststart_command: true)}
                SH
              return
            end

            # Segregate internal commands and user provided commands.
            # Before any non-blocking post start command is executed, we wait for the workspace to be marked ready.
            internal_blocking_poststart_command_ids, non_blocking_poststart_command_ids =
              poststart_command_ids.partition do |id|
                command = devfile_commands.find { |cmd| cmd[:id] == id }
                command && command.dig(:exec, :label) == INTERNAL_BLOCKING_COMMAND_LABEL
              end

            # SAST IGNORE: String interpolation in shell context is safe here
            # The interpolated method call returns validated internal script content
            # Future SAST alerts on this heredoc can be safely ignored.
            # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/547719
            configmap_data[RUN_INTERNAL_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym] =
              <<~SH.chomp
                #!/bin/sh
                #{get_poststart_command_script_content(poststart_command_ids: internal_blocking_poststart_command_ids, devfile_commands: devfile_commands, project_path: project_path, main_component_name: main_component_name)}
              SH

            # SAST IGNORE: String interpolation in shell context is safe here
            # The interpolated method call returns validated script content
            # Future SAST alerts on this heredoc can be safely ignored.
            # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/547719
            configmap_data[RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym] =
              <<~SH.chomp
                #!/bin/sh
                #{get_poststart_command_script_content(poststart_command_ids: non_blocking_poststart_command_ids, devfile_commands: devfile_commands, project_path: project_path, main_component_name: main_component_name)}
              SH

            nil
          end

          # @param [Array] poststart_command_ids
          # @param [Array<Hash>] devfile_commands
          # @param [String] project_path
          # @param [String] main_component_name
          # @param [Boolean] is_legacy_poststart_command
          # @return [String]
          def self.get_poststart_command_script_content(
            poststart_command_ids:,
            devfile_commands:,
            project_path:,
            main_component_name:,
            is_legacy_poststart_command: false
          )
            poststart_command_ids.map do |poststart_command_id|
              # NOTE: We force all the poststart scripts to exit successfully with `|| true`, to
              #       prevent the Kubernetes poststart hook from failing, and thus prevent the
              #       container from exiting. Then users can view logs to debug failures.
              #       See https://github.com/eclipse-che/che/issues/23404#issuecomment-2787779571
              #       for more context.

              # SAST IGNORE: String interpolation in shell context is safe here
              # Command IDs are validated by the devfile gem, this prevents malicious attacks like path traversal
              # Additional validation in ee/lib/remote_development/devfile_operations/restrictions_enforcer.rb
              # Future SAST alerts on this heredoc can be safely ignored.
              # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/547719

              script_execution = "#{WORKSPACE_SCRIPTS_VOLUME_PATH}/#{poststart_command_id}"
              command = devfile_commands.find { |cmd| cmd[:id] == poststart_command_id }

              unless is_legacy_poststart_command
                working_dir = command.dig(:exec, :workingDir)
                component_name = command.dig(:exec, :component)

                effective_working_dir = if working_dir.present?
                                          Shellwords.shellescape(working_dir)
                                        elsif component_name == main_component_name
                                          # Default to PROJECT_SOURCE for main component if workingDir is not specified
                                          "${PROJECT_SOURCE}/#{Shellwords.shellescape(project_path)}"
                                        end

                if effective_working_dir.present?
                  script_execution = "(cd #{effective_working_dir} && #{script_execution})"
                end
              end

              <<~SH
                echo "$(date -Iseconds): ----------------------------------------"
                echo "$(date -Iseconds): Running #{WORKSPACE_SCRIPTS_VOLUME_PATH}/#{poststart_command_id}..."
                #{script_execution} || true
                echo "$(date -Iseconds): Finished running #{WORKSPACE_SCRIPTS_VOLUME_PATH}/#{poststart_command_id}."
              SH
            end.join
          end

          private_class_method :add_devfile_command_scripts_to_configmap_data,
            :add_run_poststart_commands_script_to_configmap_data, :get_poststart_command_script_content
        end
      end
    end
  end
end
