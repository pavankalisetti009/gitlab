# frozen_string_literal: true

module RemoteDevelopment
  # This module contains constants for all the files (default devfile, shell scripts, script fragments, commands, etc)
  # that are used in the Remote Development domain. They are pulled out to separate files instead of being hardcoded
  # via inline HEREDOC or other means, so that they can have full support for
  # syntax highlighting, refactoring, linting, etc.
  module Files
    # TODO: Add a spec for this module, and auto-reload in Spring when the files change.
    #       See https://gitlab.com/gitlab-org/gitlab/-/issues/520870

    # @param [String] path - file path relative to domain logic root (this directory, `ee/lib/remote_development`)
    # @return [String] content of the file
    def self.read_file(path)
      File.read("#{__dir__}/#{path}")
    end

    ####################################
    # Please keep this list alphabetized
    ####################################

    # When updating DEFAULT_DEVFILE_YAML contents in `default_devfile.yaml`, update the user facing doc as well.
    # https://docs.gitlab.com/ee/user/workspace/#gitlab-default-devfile
    #
    # The container image is pinned to linux/amd64 digest, instead of the tag digest.
    # This is to prevent Rancher Desktop from pulling the linux/arm64 architecture of the image
    # which will disrupt local development since gitlab-workspaces-tools does not support
    # that architecture yet and thus the workspace won't start.
    # This will be fixed in https://gitlab.com/gitlab-org/workspaces/gitlab-workspaces-tools/-/issues/12
    DEFAULT_DEVFILE_YAML = read_file("settings/default_devfile.yaml")
    GIT_CREDENTIAL_STORE_SCRIPT =
      read_file("workspace_operations/create/workspace_variables_git_credential_store.sh")
    KUBERNETES_POSTSTART_HOOK_COMMAND =
      read_file("workspace_operations/reconcile/output/kubernetes_poststart_hook_command.sh")
    MAIN_COMPONENT_UPDATER_CONTAINER_ARGS =
      read_file("workspace_operations/create/main_component_updater_container_args.sh")
    MAIN_COMPONENT_UPDATER_INIT_TOOLS_SCRIPT =
      read_file("workspace_operations/create/main_component_updater_init_tools.sh")
    MAIN_COMPONENT_UPDATER_SLEEP_UNTIL_CONTAINER_IS_RUNNING_SCRIPT =
      read_file("workspace_operations/create/main_component_updater_sleep_until_workspace_is_running.sh")
    MAIN_COMPONENT_UPDATER_START_SSHD_SCRIPT =
      read_file("workspace_operations/create/main_component_updater_start_sshd.sh")
    PROJECTS_CLONER_COMPONENT_INSERTER_CONTAINER_ARGS =
      read_file("workspace_operations/create/project_cloner_component_inserter_container_args.sh")

    private_class_method :read_file
  end
end
