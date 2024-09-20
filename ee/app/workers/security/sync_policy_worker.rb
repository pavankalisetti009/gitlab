# frozen_string_literal: true

module Security
  class SyncPolicyWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky
    sidekiq_options retry: true

    deduplicate :until_executing, including_scheduled: true
    idempotent!

    feature_category :security_policy_management

    def handle_event(event)
      security_policy_id = event.data[:security_policy_id]
      Security::Policy.find_by_id(security_policy_id) || return

      case event
      when Security::PolicyDeletedEvent
        ::Security::DeleteSecurityPolicyWorker.perform_async(security_policy_id)
      end
    end
  end
end
