# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Output
        class ScriptsConfigmapAppender
          include ReconcileConstants

          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Array<Hash>] devfile_commands
          # @param [Hash] devfile_events
          # @return [void]
          def self.append(desired_config:, name:, namespace:, labels:, annotations:, devfile_commands:, devfile_events:)
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
              devfile_events: devfile_events
            )

            # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
            configmap[:data] = Gitlab::Utils.deep_sort_hashes(configmap_data).to_h

            desired_config.append(configmap)

            nil
          end

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
          # @param [Array<Hash>] devfile_commands
          # @param [Hash] devfile_events
          # @return [void]
          def self.add_run_poststart_commands_script_to_configmap_data(configmap_data:, devfile_events:)
            devfile_events => { postStart: Array => poststart_command_ids }

            script_command_lines =
              poststart_command_ids.map do |poststart_command_id|
                # NOTE: We force all the poststart scripts to exit successfully with `|| true`, to
                #       prevent the Kubernetes poststart hook from failing, and thus prevent the
                #       container from exitin. Then users can view logs to debug failures.
                #       See https://github.com/eclipse-che/che/issues/23404#issuecomment-2787779571
                #       for more context.
                <<~CMD
                  echo "$(date -Iseconds): Running #{WORKSPACE_SCRIPTS_VOLUME_PATH}/#{poststart_command_id}..."
                  #{WORKSPACE_SCRIPTS_VOLUME_PATH}/#{poststart_command_id} || true
                CMD
              end.join

            configmap_data[RUN_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym] =
              <<~SH.chomp
                #!/bin/sh
                #{script_command_lines}
              SH

            nil
          end

          private_class_method :add_devfile_command_scripts_to_configmap_data,
            :add_run_poststart_commands_script_to_configmap_data
        end
      end
    end
  end
end
