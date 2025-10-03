# frozen_string_literal: true

module Security
  class CreateDefaultTrackedContextWorker
    include ApplicationWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky
    feature_category :vulnerability_management
    idempotent!

    def handle_event(event)
      Project.find_by_id(event.data[:project_id]).try do |project|
        result = Security::ProjectTrackedContexts::CreateService.new(
          project,
          nil,
          {
            context_name: project.default_branch_or_main,
            context_type: :branch,
            is_default: true,
            track: true
          }
        ).execute

        log_error(project, result.errors) if result.error?
      end
    end

    private

    def log_error(project, errors)
      Gitlab::AppLogger.warn(
        message: "Failed to create default tracked context for project: #{errors.join(',')}",
        project_id: project.id,
        project_path: project.full_path
      )
    end
  end
end
