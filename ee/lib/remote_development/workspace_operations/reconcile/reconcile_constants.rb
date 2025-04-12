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
        WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_NAME = "gl_workspace_reconciled_actual_state.txt"
        WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_PATH =
          "#{VARIABLES_FILE_DIR}/#{WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_NAME}".freeze
      end
    end
  end
end
