# frozen_string_literal: true

module Authz
  module CustomRoles
    module UpdateServiceable
      extend ActiveSupport::Concern

      MODULE_NAME = name
      REQUIRED_METHODS = [:allowed?, :authorized_error, :role, :role_class, :params].freeze

      def self.included(base)
        REQUIRED_METHODS.each do |method_name|
          next if base.method_defined?(method_name) || base.private_method_defined?(method_name)

          base.define_method(method_name) do
            require_implementation(method_name)
          end
        end
      end

      def execute(_role)
        return authorized_error unless allowed?

        update_role
      end

      private

      def update_role
        role.assign_attributes(params.slice(:name, :description,
          *role_class.all_customizable_permissions.keys))

        if role.save
          log_audit_event(role, action: :updated)

          ::ServiceResponse.success(payload: { member_role: role })
        else
          ::ServiceResponse.error(message: role.errors.full_messages,
            payload: { member_role: role.reset })
        end
      end

      def require_implementation(method_name)
        raise NotImplementedError, "Classes including #{MODULE_NAME} must implement #{method_name}"
      end
    end
  end
end
