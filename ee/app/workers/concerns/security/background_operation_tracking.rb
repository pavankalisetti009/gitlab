# frozen_string_literal: true

module Security
  module BackgroundOperationTracking
    extend ActiveSupport::Concern

    included do
      attr_reader :operation_id, :user
    end

    def self.humanized_operation_type(operation_type)
      {
        'attribute_update' => _('Attribute update')
      }.fetch(operation_type.to_s, operation_type.to_s.humanize.downcase)
    end

    private

    def operation_exists?
      Gitlab::BackgroundOperations::RedisStore.get_operation(operation_id).present?
    end

    def record_failure(project, error_message, error_code)
      Gitlab::BackgroundOperations::RedisStore.add_failed_project(
        operation_id,
        project_id: project.id,
        project_name: project.name,
        project_full_path: project.full_path,
        error_message: error_message,
        error_code: error_code
      )
    end

    def record_success
      Gitlab::BackgroundOperations::RedisStore.increment_successful(operation_id)
    end

    def finalize_if_complete
      operation = Gitlab::BackgroundOperations::RedisStore.get_operation(operation_id)
      return unless operation
      return unless operation_complete?(operation)

      send_failure_notification(operation) if operation.failed_items > 0
      Gitlab::BackgroundOperations::RedisStore.delete_operation(operation_id)
    end

    def operation_complete?(operation)
      (operation.successful_items + operation.failed_items) >= operation.total_items
    end

    def send_failure_notification(operation)
      failed_items = Gitlab::BackgroundOperations::RedisStore.get_failed_items(operation.id)

      operation_data = {
        id: operation.id,
        operation_type: operation.operation_type,
        total_items: operation.total_items,
        successful_items: operation.successful_items,
        failed_items: operation.failed_items
      }

      Security::BackgroundOperationMailer.failure_notification(
        user: user,
        operation: operation_data,
        failed_items: failed_items
      ).deliver_later
    end
  end
end
