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

        # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Must be instance-level
        override :disable_ropc_available?
        def disable_ropc_available?
          ::Gitlab::Saas.feature_available?(:disable_ropc_for_new_applications) &&
            ::Feature.enabled?(:disable_ropc_for_new_applications)
        end
        # rubocop:enable Gitlab/FeatureFlagWithoutActor
      end

      override :execute
      def execute(request)
        super.tap do |application|
          entity = application.owner || current_user
          audit_event_service(entity, request.remote_ip).for_user(full_path: application.name, entity_id: application.id).security_event
        end
      end

      def audit_event_service(entity, ip_address)
        ::AuditEventService.new(current_user,
          entity,
          action: :custom,
          custom_message: 'OAuth application added',
          ip_address: ip_address)
      end
    end
  end
end
