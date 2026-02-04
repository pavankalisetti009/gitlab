# frozen_string_literal: true

module VirtualRegistries
  module Container
    module Cache
      module Entries
        class CreateOrUpdateService < BaseCreateOrUpdateCacheEntriesService
          extend ::Gitlab::Utils::Override

          override :entry_class
          def entry_class
            ::VirtualRegistries::Container::Cache::Remote::Entry
          end

          private

          override :skip_md5?
          def skip_md5?
            true
          end
        end
      end
    end
  end
end
