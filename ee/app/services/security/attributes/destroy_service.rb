# frozen_string_literal: true

module Security
  module Attributes
    class DestroyService < BaseService
      def initialize(attribute:, current_user:)
        @attribute = attribute
        @current_user = current_user
      end

      def execute
        raise Gitlab::Access::AccessDeniedError unless feature_enabled?

        return UnauthorizedError unless permitted?

        return not_editable_error unless attribute.editable?

        deleted_attribute_gid = attribute.to_global_id

        attribute.destroy ? success(deleted_attribute_gid) : deletion_failed_error("Failed to delete attribute")

      rescue ActiveRecord::RecordNotDestroyed => e
        deletion_failed_error(e.message)
      end

      private

      attr_reader :attribute, :current_user

      def permitted?
        Ability.allowed?(current_user, :admin_security_attributes, attribute.security_category)
      end

      def feature_enabled?
        root_namespace = attribute.security_category.namespace&.root_ancestor
        Feature.enabled?(:security_categories_and_attributes, root_namespace)
      end

      def success(deleted_attribute_gid)
        enqueue_project_associations_cleanup
        ServiceResponse.success(payload: { deleted_attribute_gid: deleted_attribute_gid })
      end

      def enqueue_project_associations_cleanup
        Security::Attributes::CleanupProjectToSecurityAttributeWorker.perform_async(attribute.id)
      end

      def error_response(message)
        ServiceResponse.error(message: message, payload: [message])
      end

      def not_editable_error
        error_response("Cannot delete non-editable attribute")
      end

      def deletion_failed_error(error_message)
        error_response("Failed to delete attributes: #{error_message}")
      end
    end
  end
end
