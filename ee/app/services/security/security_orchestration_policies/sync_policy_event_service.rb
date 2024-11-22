# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncPolicyEventService < BaseProjectPolicyService
      def initialize(project:, security_policy:, event:)
        super(project: project, security_policy: security_policy)
        @event = event
      end

      def execute
        case event
        when Projects::ComplianceFrameworkChangedEvent
          sync_policy_for_compliance_framework(event)
        end
      end

      private

      def sync_policy_for_compliance_framework(event)
        return unless security_policy.scope_has_framework?(event.data[:compliance_framework_id])

        if event.data[:event_type] == Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added]
          link_policy
        else
          unlink_policy
        end
      end

      attr_reader :event
    end
  end
end
