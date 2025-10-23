# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class CreateWarnModeAuditEventsWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :sticky

      # This worker isn't idempotent because policy edits can't be told apart by
      # their idenity. However `EventStore::Subscriber` enforces the idempotency
      # attribute.
      idempotent!

      feature_category :security_policy_management

      def handle_event(event)
        security_policy_id = event.data[:security_policy_id]
        policy = Security::Policy.find_by_id(security_policy_id) || return

        return unless policy.enabled? && policy.warn_mode? && create_audit_event?(event)

        policy.security_orchestration_policy_configuration.all_project_ids do |project_ids|
          ::Security::ScanResultPolicies::CreateProjectWarnModeAuditEventsWorker.bulk_perform_async_with_contexts(
            project_ids,
            arguments_proc: ->(project_id) { [project_id, policy.id] },
            context_proc: ->(_) { config_context(policy) }
          )
        end
      end

      private

      def create_audit_event?(event)
        case event
        when Security::PolicyCreatedEvent then true
        when Security::PolicyUpdatedEvent then event.data[:diff].key?(:approval_settings)
        else raise "unrecognized event: #{event.class.name}"
        end
      end

      def config_context(policy)
        if policy.security_orchestration_policy_configuration.namespace?
          { namespace: policy.security_orchestration_policy_configuration.namespace }
        else
          { project: policy.security_orchestration_policy_configuration.project }
        end
      end
    end
  end
end
