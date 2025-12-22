# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      module Cache
        module Remote
          class Entry < ApplicationRecord
            include ShaAttribute

            self.primary_key = %i[group_id iid]

            belongs_to :group, optional: false
            belongs_to :upstream, class_name: 'VirtualRegistries::Packages::Maven::Upstream', optional: false

            validates :group, top_level_group: true

            enum :status, default: 0, processing: 1, pending_destruction: 2, error: 3

            sha_attribute :file_sha1
            sha_attribute :file_md5
          end
        end
      end
    end
  end
end
