# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class SaasInitialIndexingEventWorker
        include Gitlab::EventStore::Subscriber
        include Gitlab::Utils::StrongMemoize
        prepend ::Geo::SkipSecondary

        feature_category :global_search
        deduplicate :until_executed
        data_consistency :sticky
        urgency :low
        idempotent!
        defer_on_database_health_signal :gitlab_main,
          [:p_ai_active_context_code_enabled_namespaces, :gitlab_subscriptions, :subscription_add_on_purchases],
          10.minutes

        def handle_event(_); end
      end
    end
  end
end
