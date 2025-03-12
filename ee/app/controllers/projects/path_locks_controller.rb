# frozen_string_literal: true

module Projects
  class PathLocksController < Projects::ApplicationController
    include PathLocksHelper

    # Authorize
    before_action :require_non_empty_project
    before_action :authorize_read_code!
    before_action :authorize_push_code!, only: [:toggle]

    before_action :check_license

    feature_category :source_code_management
    urgency :low, [:index]

    def index
      @path_locks = @project.path_locks.page(allowed_params[:page])
    end

    def toggle
      path_lock = @project.path_locks.for_path(path)

      if path_lock
        unlock_file(path_lock)
      else
        lock_file
      end

      head :ok
    rescue PathLocks::UnlockService::AccessDenied, PathLocks::LockService::AccessDenied
      access_denied!
    end

    def destroy
      path_lock = @project.path_locks.find(allowed_params[:id])

      begin
        PathLocks::UnlockService.new(project, current_user).execute(path_lock)
      rescue PathLocks::UnlockService::AccessDenied
        return access_denied!
      end

      respond_to do |format|
        format.html do
          redirect_to project_locks_path(@project), status: :found
        end
        format.js
      end
    end

    private

    def check_license
      unless @project.feature_available?(:file_locks)
        flash[:alert] = _('You need a different license to enable FileLocks feature')
        redirect_to admin_subscription_path
      end
    end

    def lock_file
      PathLocks::LockService.new(project, current_user).execute(path)
    end

    def unlock_file(path_lock)
      PathLocks::UnlockService.new(project, current_user).execute(path_lock)
    end

    def lfs_file?
      blob = repository.blob_at_branch(repository.root_ref, path)

      return false unless blob

      lfs_blob_ids = LfsPointersFinder.new(repository, path).execute

      lfs_blob_ids.include?(blob.id)
    end

    def sync_with_lfs?
      project.lfs_enabled? && lfs_file?
    end

    def path
      allowed_params[:path]
    end

    def allowed_params
      params.permit(:path, :id, :page)
    end
  end
end
