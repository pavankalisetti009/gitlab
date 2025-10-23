# frozen_string_literal: true

module Security
  module Categories
    class CreateService < BaseService
      def initialize(namespace:, params:, current_user:)
        @root_namespace = namespace&.root_ancestor
        @params = params
        @current_user = current_user
        @category = Security::Category.new
      end

      def execute
        unless Feature.enabled?(:security_categories_and_attributes, root_namespace)
          raise Gitlab::Access::AccessDeniedError
        end

        return UnauthorizedError unless permitted?

        return error if CreatePredefinedService.new(namespace: root_namespace, current_user: current_user)
          .execute.error?

        category.assign_attributes(
          namespace: root_namespace,
          name: params[:name],
          description: params[:description],
          editable_state: params[:editable_state] || :editable,
          template_type: params[:template_type],
          multiple_selection: params[:multiple_selection] || false
        )
        return error unless category.save

        create_audit_event
        success
      end

      attr_reader :root_namespace, :params, :current_user, :category

      private

      def permitted?
        current_user.can?(:admin_security_attributes, root_namespace)
      end

      def success
        ServiceResponse.success(payload: { category: category })
      end

      def error
        ServiceResponse.error(message: _('Failed to create security category'), payload: category.errors)
      end

      def create_audit_event
        audit_context = {
          name: 'security_category_created',
          author: current_user,
          scope: root_namespace,
          target: category,
          message: "Created security category #{category.name}",
          additional_details: {
            category_name: category.name,
            category_description: category.description,
            multiple_selection: category.multiple_selection,
            template_type: category.template_type
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
