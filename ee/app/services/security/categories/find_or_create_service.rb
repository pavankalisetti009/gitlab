# frozen_string_literal: true

module Security
  module Categories
    class FindOrCreateService < BaseService
      def initialize(namespace:, current_user:, category_id: nil, template_type: nil)
        @namespace = namespace&.root_ancestor
        @category_id = category_id
        @template_type = template_type
        @current_user = current_user
      end

      def execute
        return ServiceResponse.error(message: 'Namespace not found') unless namespace.present?
        raise Gitlab::Access::AccessDeniedError unless Feature.enabled?(:security_categories_and_attributes, namespace)
        return UnauthorizedError unless permitted?

        predefined_result = CreatePredefinedService.new(namespace: namespace, current_user: current_user).execute
        return predefined_result if predefined_result.error?

        category = find_category
        if category
          ServiceResponse.success(payload: { category: category })
        else
          ServiceResponse.error(message: 'Category not found')
        end
      end

      private

      attr_reader :category_id, :template_type, :namespace, :current_user

      def find_category
        if category_id
          ::Security::Category.find_by_id(category_id)
        elsif template_type && namespace
          ::Security::Category.by_namespace_and_template_type(namespace.root_ancestor, template_type).first
        end
      end

      def permitted?
        current_user.can?(:admin_security_attributes, namespace)
      end
    end
  end
end
