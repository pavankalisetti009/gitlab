# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class MainComponentUpdater
        include Messages

        # @param [Hash] context
        # @return [Hash]
        def self.update(context)
          context => {
            processed_devfile: Hash => processed_devfile,
            volume_mounts: Hash => volume_mounts,
            vscode_extensions_gallery_metadata: Hash => vscode_extensions_gallery_metadata
          }
          volume_mounts => { data_volume: Hash => data_volume }
          data_volume => { path: String => volume_path }

          editor_port = WorkspaceCreator::WORKSPACE_PORT
          ssh_port = 60022
          tools_dir = "#{volume_path}/.gl-tools"

          # NOTE: We will always have exactly one main_component found, because we have already
          #       validated this in post_flatten_devfile_validator.rb
          main_component = processed_devfile['components'].find { |c| c.dig('attributes', 'gl/inject-editor') }

          update_main_container(
            main_component: main_component,
            tools_dir: tools_dir,
            editor_port: editor_port,
            ssh_port: ssh_port,
            enable_marketplace: vscode_extensions_gallery_metadata.fetch(:enabled)
          )

          context
        end

        # @param [Hash] main_component
        # @param [String] tools_dir
        # @param [Integer] editor_port
        # @param [Integer] ssh_port
        # @param [Boolean] enable_marketplace
        # @return [void]
        def self.update_main_container(main_component:, tools_dir:, editor_port:, ssh_port:, enable_marketplace:)
          # This overrides the main container's command
          # Open issue to support both starting the editor and running the default command:
          # https://gitlab.com/gitlab-org/gitlab/-/issues/392853
          container_args = <<~"SH".chomp
            sshd_path=$(which sshd)
            if [ -x "$sshd_path" ]; then
              echo "Starting sshd on port ${GL_SSH_PORT}"
              $sshd_path -D -p $GL_SSH_PORT &
            else
              echo "'sshd' not found in path. Not starting SSH server."
            fi
            ${GL_TOOLS_DIR}/init_tools.sh
          SH
          main_component['container']['command'] = %w[/bin/sh -c]
          main_component['container']['args'] = [container_args]
          main_component['container']['env'] = [] if main_component['container']['env'].nil?
          main_component['container']['env'] += [
            {
              'name' => 'GL_TOOLS_DIR',
              'value' => tools_dir
            },
            {
              'name' => 'GL_EDITOR_LOG_LEVEL',
              'value' => 'info'
            },
            {
              'name' => 'GL_EDITOR_PORT',
              'value' => editor_port.to_s
            },
            {
              'name' => 'GL_SSH_PORT',
              'value' => ssh_port.to_s
            },
            {
              'name' => 'GL_EDITOR_ENABLE_MARKETPLACE',
              'value' => enable_marketplace.to_s
            }
          ]

          main_component['container']['endpoints'] = [] if main_component['container']['endpoints'].nil?
          main_component['container']['endpoints'].append(
            {
              'name' => 'editor-server',
              'targetPort' => editor_port,
              'exposure' => 'public',
              'secure' => true,
              'protocol' => 'https'
            },
            {
              'name' => 'ssh-server',
              'targetPort' => ssh_port,
              'exposure' => 'internal',
              'secure' => true
            }
          )
        end

        private_class_method :update_main_container
      end
    end
  end
end
