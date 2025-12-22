# frozen_string_literal: true

module EE
  module VirtualRegistries
    module Packages
      module Cache
        module DestroyOrphanEntriesWorker
          extend ::Gitlab::Utils::Override

          # a no-op worker that should be removed in 18.10 according to
          # https://docs.gitlab.com/development/sidekiq/compatibility_across_updates/#removing-worker-classes
          override :perform_work
          def perform_work(_model); end
        end
      end
    end
  end
end
