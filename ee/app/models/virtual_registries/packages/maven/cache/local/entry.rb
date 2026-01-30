# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      module Cache
        module Local
          class Entry < ApplicationRecord
            include ::VirtualRegistries::Local

            self.primary_key = %i[group_id iid]

            belongs_to :group
            belongs_to :upstream,
              class_name: 'VirtualRegistries::Packages::Maven::Local::Upstream',
              inverse_of: :cache_entries,
              optional: false
            belongs_to :package_file,
              class_name: 'Packages::PackageFile',
              optional: false

            validates :group, top_level_group: true, presence: true
            validates :relative_path, :upstream_checked_at, presence: true
            validates :relative_path, length: { maximum: 1024 }
            validates :relative_path, format: { without: /\s/, message: 'must not contain spaces' }
            validates :relative_path, uniqueness: { scope: [:upstream_id, :group_id] }

            delegate :file, :file_sha1, :file_md5, to: :package_file, allow_nil: true

            scope :for_group, ->(group) { where(group:) }
            scope :for_upstream, ->(upstream) { where(upstream:) }
          end
        end
      end
    end
  end
end
