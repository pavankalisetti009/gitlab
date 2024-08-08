# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class ProjectClonerComponentInjector
        include Messages

        # @param [Hash] context
        # @return [Hash]
        def self.inject(context)
          context => {
            processed_devfile: Hash => processed_devfile,
            volume_mounts: Hash => volume_mounts,
            params: Hash => params,
            settings: Hash => settings
          }
          volume_mounts => { data_volume: Hash => data_volume }
          data_volume => { path: String => volume_path }
          params => {
            project: Project => project,
            devfile_ref: String => devfile_ref,
          }
          settings => {
            project_cloner_image: String => image,
          }
          project_cloning_successful_file = "#{volume_path}/.gl_project_cloning_successful"

          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/408448
          #       replace the alpine/git docker image with one that is published by gitlab for security / reliability
          #       reasons
          clone_dir = "#{volume_path}/#{project.path}"
          project_url = project.http_url_to_repo

          # The project should be cloned only if one is not cloned successfully already.
          # This is required to avoid resetting user's modifications to the files.
          # This is achieved by checking for the existence of a file before cloning.
          # If the file does not exist, clone the project.
          # To accommodate for scenarios where the project cloning failed midway in the previous attempt,
          # remove the directory before cloning.
          # Once cloning is successful, create the file which is used in the check above.
          # This will ensure the project is not cloned again on restarts.
          container_args = <<~SH.chomp
            if [ -f "${GL_PROJECT_CLONING_SUCCESSFUL_FILE}" ];
            then
              echo "Project cloning was already successful";
              exit 0;
            fi
            if [ -d "#{Shellwords.shellescape(clone_dir)}" ];
            then
              echo "Removing unsuccessfully cloned project directory";
              rm -rf "#{Shellwords.shellescape(clone_dir)}";
            fi
            echo "Cloning project";
            git clone --branch "#{Shellwords.shellescape(devfile_ref)}" "#{Shellwords.shellescape(project_url)}" "#{Shellwords.shellescape(clone_dir)}";
            exit_code=$?
            if [ "${exit_code}" -eq 0 ];
            then
              echo "Project cloning successful";
              touch "${GL_PROJECT_CLONING_SUCCESSFUL_FILE}";
              echo "Updated file to indicate successful project cloning";
              exit 0;
            else
              echo "Project cloning failed with exit code: ${exit_code}";
              exit "${exit_code}";
            fi
          SH

          # TODO: https://gitlab.com/groups/gitlab-org/-/epics/10461
          #       implement better error handling to allow cloner to be able to deal with different categories of errors
          # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/408451
          cloner_component = {
            'name' => 'gl-cloner-injector',
            'container' => {
              'image' => image,
              'args' => [container_args],
              # command has been overridden here as the default command in the alpine/git
              # container invokes git directly
              'command' => %w[/bin/sh -c],
              'env' => [
                {
                  'name' => 'GL_PROJECT_CLONING_SUCCESSFUL_FILE',
                  'value' => project_cloning_successful_file
                }
              ],
              'memoryLimit' => '512Mi',
              'memoryRequest' => '256Mi',
              'cpuLimit' => '500m',
              'cpuRequest' => '100m'
            }
          }

          processed_devfile['components'] ||= []
          processed_devfile['components'] << cloner_component

          # create a command that will invoke the cloner
          cloner_command = {
            'id' => 'gl-cloner-injector-command',
            'apply' => {
              'component' => cloner_component['name']
            }
          }
          processed_devfile['commands'] ||= []
          processed_devfile['commands'] << cloner_command

          # configure the workspace to run the cloner command upon workspace start
          processed_devfile['events'] ||= {}
          processed_devfile['events']['preStart'] ||= []
          processed_devfile['events']['preStart'] << cloner_command['id']

          context
        end
      end
    end
  end
end
