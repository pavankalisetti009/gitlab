# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Npm
      module Cache
        module Remote
          class Entry < ApplicationRecord
            include ShaAttribute

            self.primary_key = %i[group_id iid]

            belongs_to :group, optional: false
            belongs_to :upstream,
              class_name: 'VirtualRegistries::Packages::Npm::Upstream',
              inverse_of: :cache_remote_entries,
              optional: false

            enum :status, { default: 0, processing: 1, pending_destruction: 2, error: 3 }

            sha_attribute :file_sha1
            sha_attribute :file_md5

            before_validation :set_object_storage_key, if: -> { object_storage_key.blank? && upstream }

            private

            def set_object_storage_key
              self.object_storage_key = upstream.object_storage_key
            end
          end
        end
      end
    end
  end
end
