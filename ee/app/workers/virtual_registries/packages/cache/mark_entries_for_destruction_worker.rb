# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Cache
      class MarkEntriesForDestructionWorker
        include ApplicationWorker

        data_consistency :sticky
        queue_namespace :dependency_proxy_blob
        feature_category :virtual_registry
        urgency :low
        defer_on_database_health_signal :gitlab_main, [:virtual_registries_packages_maven_cache_entries], 5.minutes
        deduplicate :until_executed
        idempotent!

        # a no-op worker that should be removed in 18.9 according to
        # https://docs.gitlab.com/development/sidekiq/compatibility_across_updates/#removing-worker-classes
        def perform(upstream_id); end
      end
    end
  end
end
