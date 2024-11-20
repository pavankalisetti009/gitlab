# frozen_string_literal: true

module EE
  module Ci
    module Runners
      # Unregisters CI Runners in bulk and logs an audit event
      #
      module BulkDeleteRunnersService
        extend ::Gitlab::Utils::Override

        override :execute
        def execute
          super.tap do |result|
            next unless runners && result.success?

            audit_event(result.payload[:deleted_models])
          end
        end

        private

        def audit_event(runners)
          ::AuditEvents::BulkDeleteRunnersAuditEventService.new(runners, current_user).track_event
        end
      end
    end
  end
end
