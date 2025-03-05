# frozen_string_literal: true

module EE
  module Lfs
    module LockFileService
      def execute
        result = super

        create_path_lock(result[:lock].path) if create_path_lock?(result[:status])

        result
      end

      private

      def create_path_lock?(lfs_lock_status)
        lfs_lock_status == :success &&
          params[:create_path_lock] != false &&
          project.feature_available?(:file_locks)
      end

      def create_path_lock(path)
        PathLocks::LockService.new(project, current_user).execute(path)
      end
    end
  end
end
