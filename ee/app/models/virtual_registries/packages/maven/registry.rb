# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      class Registry < ::VirtualRegistries::Registry
        MAX_REGISTRY_COUNT = 20

        has_many :registry_upstreams,
          -> { order(position: :asc) },
          class_name: 'VirtualRegistries::Packages::Maven::RegistryUpstream',
          inverse_of: :registry
        has_many :upstreams,
          class_name: 'VirtualRegistries::Packages::Maven::Upstream',
          through: :registry_upstreams

        def purge_cache!
          ::VirtualRegistries::Packages::Cache::MarkEntriesForDestructionWorker.bulk_perform_async_with_contexts(
            exclusive_upstreams,
            arguments_proc: ->(upstream) { [upstream.id] },
            context_proc: ->(upstream) { { namespace: upstream.group } }
          )
        end
      end
    end
  end
end
