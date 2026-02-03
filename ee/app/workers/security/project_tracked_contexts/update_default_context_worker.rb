# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    class UpdateDefaultContextWorker
      include ApplicationWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :sticky
      feature_category :vulnerability_management
      deduplicate :until_executed, if_deduplicated: :reschedule_once
      idempotent!

      def handle_event(event)
        container_id = event.data[:container_id]
        container_type = event.data[:container_type]

        return unless container_type == 'Project'

        Project.find_by_id(container_id).try do |project|
          next unless Feature.enabled?(:update_default_security_tracked_contexts_worker, project)

          result = Security::ProjectTrackedContexts::UpdateDefaultContextService.new(project).execute

          log_error(project, result.errors) if result.error?
        end
      end

      private

      def log_error(project, errors)
        Gitlab::AppLogger.warn(
          message: "Failed to update default tracked context for project: #{errors.join(',')}",
          project_id: project.id,
          project_path: project.full_path
        )
      end
    end
  end
end
