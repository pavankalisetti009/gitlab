# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class ToolsInjectorComponentInserter
        include Messages

        # @param [Hash] context
        # @return [Hash]
        def self.insert(context)
          context => {
            processed_devfile: Hash => processed_devfile,
            volume_mounts: Hash => volume_mounts,
            settings: Hash => settings,
          }
          volume_mounts => { data_volume: Hash => data_volume }
          data_volume => { path: String => volume_path }
          settings => { tools_injector_image: String => image_from_settings }

          tools_dir = "#{volume_path}/.gl-tools"
          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409775 - choose image based on which editor is passed.
          insert_tools_injector_component(
            processed_devfile: processed_devfile,
            tools_dir: tools_dir,
            image: image_from_settings
          )

          context
        end

        # @param [Hash] processed_devfile
        # @param [String] tools_dir
        # @param [String] image
        # @return [void]
        def self.insert_tools_injector_component(processed_devfile:, tools_dir:, image:)
          component_name = 'gl-tools-injector'

          tools_injector_component = {
            'name' => component_name,
            'container' => {
              'image' => image,
              'env' => [
                {
                  'name' => 'GL_TOOLS_DIR',
                  'value' => tools_dir
                }
              ],
              'memoryLimit' => '512Mi',
              'memoryRequest' => '256Mi',
              'cpuLimit' => '500m',
              'cpuRequest' => '100m'
            }
          }
          processed_devfile['components'] << tools_injector_component

          processed_devfile['commands'] = [] if processed_devfile['commands'].nil?

          command_name = "#{component_name}-command"
          processed_devfile['commands'] += [{
            'id' => command_name,
            'apply' => {
              'component' => component_name
            }
          }]

          processed_devfile['events'] = {} if processed_devfile['events'].nil?
          processed_devfile['events']['preStart'] = [] if processed_devfile['events']['preStart'].nil?
          processed_devfile['events']['preStart'] += [command_name]

          nil
        end

        private_class_method :insert_tools_injector_component
      end
    end
  end
end
