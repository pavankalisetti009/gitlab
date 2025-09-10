# frozen_string_literal: true

module Security
  module Attributes
    class CreateService < BaseService
      def initialize(category:, namespace:, params:, current_user:)
        @category = category
        @root_namespace = namespace&.root_ancestor
        @params = params
        @current_user = current_user
        @attributes = []
      end

      def execute
        unless Feature.enabled?(:security_categories_and_attributes, root_namespace)
          raise Gitlab::Access::AccessDeniedError
        end

        return UnauthorizedError unless permitted?
        return non_editable unless category.editable?

        @attributes = params[:attributes].map do |attribute_params|
          category.security_attributes.build(
            namespace: root_namespace,
            name: attribute_params[:name],
            description: attribute_params[:description],
            color: attribute_params[:color],
            editable_state: :editable
          )
        end

        return error(attributes.select(&:invalid?)) if attributes.any?(&:invalid?) || !category.valid?

        category.save ? success : error # Saving the category saves its attributes
      end

      attr_reader :category, :root_namespace, :params, :current_user, :attributes

      private

      def permitted?
        current_user.can?(:admin_security_attributes, category)
      end

      def success
        ServiceResponse.success(payload: { attributes: attributes })
      end

      def non_editable
        ServiceResponse.error(message: "You can not edit this category's attributes.")
      end

      def error(failed_attributes = attributes)
        errors = failed_attributes.map(&:errors).flat_map(&:full_messages).uniq + category.errors.full_messages
        message = "Failed to create security attributes"
        message += ": #{errors.join(', ')}" if errors.any?
        ServiceResponse.error(message: message, payload: errors)
      end
    end
  end
end
