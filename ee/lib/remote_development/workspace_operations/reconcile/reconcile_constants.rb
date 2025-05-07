# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      # NOTE: Constants are scoped to the use-case namespace in which they are used in production
      #       code (but they may still be referenced by specs or fixtures or factories).
      #       For example, this RemoteDevelopment::WorkspaceOperations::Create::CreateConstants
      #       file contains constants which are only used by classes within that namespace.
      #
      #       See documentation at ../../README.md#constant-declarations for more information.
      module ReconcileConstants
        include WorkspaceOperationsConstants

        # Please keep alphabetized
        RUN_AS_USER = 5001
        RUN_POSTSTART_COMMANDS_SCRIPT_NAME = "gl-run-poststart-commands.sh"
        WORKSPACE_SCRIPTS_VOLUME_DEFAULT_MODE = 0o555
        WORKSPACE_SCRIPTS_VOLUME_NAME = "gl-workspace-scripts"
        WORKSPACE_SCRIPTS_VOLUME_PATH = "/workspace-scripts"
      end
    end
  end
end
