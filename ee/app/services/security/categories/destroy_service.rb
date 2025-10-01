# frozen_string_literal: true

module Security
  module Categories
    class DestroyService < BaseService
      def initialize(category:, current_user:)
        @category = category
        @current_user = current_user
      end

      def execute
        raise Gitlab::Access::AccessDeniedError unless feature_enabled?

        return UnauthorizedError unless permitted?
        return not_editable_error unless category.editable?

        deleted_category_gid = category.to_global_id
        deleted_attributes_id_to_gid = category.security_attributes.to_h do |attribute|
          [attribute.id, attribute.to_global_id]
        end

        Security::Category.transaction do
          category.security_attributes.destroy_all # rubocop:disable Cop/DestroyAll -- Need destroy callbacks to trigger worker for project association cleanup
          category.destroy
        end

        success(deleted_category_gid, deleted_attributes_id_to_gid)
      rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::StatementInvalid => e
        deletion_failed_error(e.message)
      end

      attr_reader :category, :current_user

      private

      def permitted?
        current_user.can?(:admin_security_attributes, category.namespace)
      end

      def feature_enabled?
        root_namespace = category.namespace&.root_ancestor
        Feature.enabled?(:security_categories_and_attributes, root_namespace)
      end

      def success(deleted_category_gid, deleted_attributes_id_to_gid)
        enqueue_project_associations_cleanup(deleted_attributes_id_to_gid.keys)
        ServiceResponse.success(payload:
                                  {
                                    deleted_category_gid: deleted_category_gid,
                                    deleted_attributes_gid: deleted_attributes_id_to_gid.values
                                  })
      end

      def enqueue_project_associations_cleanup(attribute_ids)
        Security::Attributes::CleanupProjectToSecurityAttributeWorker.perform_async(attribute_ids)
      end

      def error_response(message)
        ServiceResponse.error(message: message, payload: [message])
      end

      def not_editable_error
        error_response("Cannot delete non-editable category")
      end

      def deletion_failed_error(error_message)
        error_response("Failed to delete category: #{error_message}")
      end
    end
  end
end
