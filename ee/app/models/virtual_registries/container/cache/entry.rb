# frozen_string_literal: true

module VirtualRegistries
  module Container
    module Cache
      class Entry < ApplicationRecord
        include FileStoreMounter
        include Gitlab::SQL::Pattern
        include ShaAttribute
        include CounterAttribute

        self.primary_key = %i[upstream_id relative_path status]

        belongs_to :group
        belongs_to :upstream,
          class_name: 'VirtualRegistries::Container::Upstream',
          inverse_of: :cache_entries,
          optional: false

        alias_method :namespace, :group

        # Used in destroying stale cached responses in DestroyOrphanCachedEntriesWorker
        enum :status, default: 0, processing: 1, pending_destruction: 2, error: 3

        sha_attribute :file_sha1
        sha_attribute :file_md5

        validates :group, top_level_group: true, presence: true
        validates :relative_path,
          :object_storage_key,
          :size,
          :file_sha1,
          presence: true
        validates :upstream_etag, :content_type, length: { maximum: 255 }
        validates :relative_path, :object_storage_key, length: { maximum: 1024 }
        validates :file_md5, length: { is: 32 }, allow_nil: true
        validates :file_sha1, length: { is: 40 }
        validates :relative_path,
          uniqueness: { scope: [:upstream_id, :status] },
          if: :default?
        validates :object_storage_key, uniqueness: { scope: :relative_path }
        validates :file, presence: true

        before_validation :set_object_storage_key, if: -> { object_storage_key.blank? && upstream }
        attr_readonly :object_storage_key

        private

        def set_object_storage_key
          self.object_storage_key = upstream.object_storage_key
        end
      end
    end
  end
end
