# frozen_string_literal: true

module EE
  module Lfs
    module UnlockFileService
      def execute
        result = super

        destroy_path_lock(result[:lock].path) if destroy_path_lock?(result[:status])

        result
      end

      private

      def destroy_path_lock?(lfs_lock_status)
        lfs_lock_status == :success &&
          params[:destroy_path_lock] != false &&
          project.feature_available?(:file_locks)
      end

      def destroy_path_lock(path)
        path_lock = project.path_locks.for_path(path)

        return unless path_lock

        PathLocks::UnlockService.new(project, current_user).execute(path_lock)
      end
    end
  end
end
