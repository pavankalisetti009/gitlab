# frozen_string_literal: true

module EE
  module Applications
    module CreateService
      extend ::Gitlab::Utils::Override

      def self.prepended(base)
        base.singleton_class.prepend(ClassMethods)
      end

      module ClassMethods
        extend ::Gitlab::Utils::Override

        override :disable_ropc_available?
        def disable_ropc_available?
          ::Gitlab::Saas.feature_available?(:disable_ropc_for_new_applications)
        end

        override :disable_ropc_for_all_applications?
        def disable_ropc_for_all_applications?
          ::Gitlab::Saas.feature_available?(:disable_ropc_for_all_applications)
        end
      end

      override :execute
      def execute
        super.tap do |application|
          # NOTE: These guard clauses exist to avoid errors when this service is invoked from an internal
          #       API, such as KAS. In this case, the request may not have a `remote_ip` method, and the
          #       application.owner and/or current_user may not be present. We also don't want to pass nil for these,
          #       value because this may break the contract/behavior of the audit logic, which may expect them in
          #       to be present and fail if they are not.

          next unless request.present?

          next unless request.respond_to?(:remote_ip)

          entity = application.owner || current_user

          next unless entity

          audit_oauth_application_creation(application, request.remote_ip, entity)
        end
      end

      private

      def audit_oauth_application_creation(application, ip_address, entity)
        ::Gitlab::Audit::Auditor.audit(
          name: 'oauth_application_created',
          author: current_user,
          scope: entity,
          target: application,
          message: 'OAuth application added',
          additional_details: {
            application_name: application.name,
            application_id: application.id,
            scopes: application.scopes.to_a,
            redirect_uri: application.redirect_uri[0, 100]
          },
          ip_address: ip_address
        )
      end
    end
  end
end
