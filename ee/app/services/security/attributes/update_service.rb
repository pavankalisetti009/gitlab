# frozen_string_literal: true

module Security
  module Attributes
    class UpdateService < BaseService
      def initialize(attribute:, params:, current_user:)
        @attribute = attribute
        @root_namespace = attribute.namespace&.root_ancestor
        @params = params
        @current_user = current_user
      end

      def execute
        unless Feature.enabled?(:security_categories_and_attributes, root_namespace)
          raise Gitlab::Access::AccessDeniedError
        end

        return UnauthorizedError unless permitted?
        return ServiceResponse.error(message: 'Cannot update non editable attribute') unless attribute.editable?

        attribute.assign_attributes(params.slice(:name, :description, :color))
        attribute.save ? success : error
      end

      attr_reader :attribute, :root_namespace, :params, :current_user

      private

      def permitted?
        current_user.can?(:admin_security_attributes, attribute.security_category)
      end

      def success
        ServiceResponse.success(payload: { attribute: attribute })
      end

      def error
        errors = attribute.errors.full_messages
        message = "Failed to update security attribute"
        message += ": #{errors.join(', ')}" if errors.any?
        ServiceResponse.error(message: message, payload: errors)
      end
    end
  end
end
