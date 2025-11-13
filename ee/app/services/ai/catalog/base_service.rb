# frozen_string_literal: true

module Ai
  module Catalog
    class BaseService < ::BaseContainerService
      include Gitlab::InternalEventsTracking

      DEFAULT_VERSION = '1.0.0'

      def initialize(project:, current_user:, params: {})
        super(container: project, current_user: current_user, params: params)
      end

      private

      def allowed?
        Ability.allowed?(current_user, :admin_ai_catalog_item, project)
      end

      def error(message, payload: {})
        ServiceResponse.error(message: Array(message), payload: payload)
      end

      def error_no_permissions(payload: {})
        ServiceResponse.error(message: ['You have insufficient permissions'], payload: payload)
      end

      def track_ai_item_events(event_type, additional_properties = {})
        track_internal_event(
          event_type,
          user: current_user,
          project: project,
          additional_properties: additional_properties
        )
      end

      def send_audit_events(event_type, item, params = {})
        messages = audit_event_messages(event_type, item, params)

        messages.each do |message|
          audit_context = {
            name: event_type,
            author: current_user,
            scope: project,
            target: item,
            target_details: "#{item.name} (ID: #{item.id})",
            message: message
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end
      end

      def audit_event_messages(event_type, item, params)
        service_class = "::Ai::Catalog::#{item.item_type.to_s.camelize.pluralize}::" \
          "AuditEventMessageService".safe_constantize

        return [] if service_class.nil?

        service_class.new(event_type, item, params).messages
      end
    end
  end
end
