# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Npm
      class RegistryUpstream < ApplicationRecord
        MAX_UPSTREAMS_COUNT = 20

        belongs_to :group

        belongs_to :registry,
          class_name: '::VirtualRegistries::Packages::Npm::Registry',
          inverse_of: :registry_upstreams
        belongs_to :upstream,
          class_name: '::VirtualRegistries::Packages::Npm::Upstream',
          inverse_of: :registry_upstreams

        validates :upstream_id, uniqueness: { scope: :registry_id }
        validates :registry_id, uniqueness: { scope: [:position] }

        validates :group, top_level_group: true, presence: true
        validates :position,
          numericality: {
            only_integer: true,
            greater_than_or_equal_to: 1,
            less_than_or_equal_to: MAX_UPSTREAMS_COUNT
          },
          presence: true

        before_validation :set_group, :set_position, on: :create

        private

        def set_group
          self.group ||= (registry || upstream).group
        end

        def set_position
          self.position = self.class.where(registry:, group:).maximum(:position).to_i + 1
        end
      end
    end
  end
end
