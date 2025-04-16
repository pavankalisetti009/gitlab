# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      class Registry < ApplicationRecord
        belongs_to :group
        has_many :registry_upstreams,
          -> { order(position: :asc) },
          class_name: 'VirtualRegistries::Packages::Maven::RegistryUpstream',
          inverse_of: :registry
        has_many :upstreams,
          class_name: 'VirtualRegistries::Packages::Maven::Upstream',
          through: :registry_upstreams

        validates :group, top_level_group: true, presence: true, uniqueness: true

        scope :for_group, ->(group) { where(group: group) }

        before_destroy :delete_upstreams

        private

        def delete_upstreams
          VirtualRegistries::Packages::Maven::Upstream
            .primary_key_in(registry_upstreams.select(:upstream_id))
            .delete_all
        end
      end
    end
  end
end
