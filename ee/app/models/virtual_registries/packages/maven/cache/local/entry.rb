# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      module Cache
        module Local
          class Entry < ApplicationRecord
            self.primary_key = %i[upstream_id relative_path]

            belongs_to :group
            belongs_to :upstream,
              class_name: 'VirtualRegistries::Packages::Maven::Upstream',
              inverse_of: :cache_local_entries,
              optional: false
            belongs_to :package_file,
              class_name: 'Packages::PackageFile',
              optional: false

            validates :group, top_level_group: true, presence: true
            validates :relative_path, presence: true
            validates :relative_path, length: { maximum: 1024 }
            validates :relative_path, format: { without: /\s/, message: 'must not contain spaces' }
          end
        end
      end
    end
  end
end
