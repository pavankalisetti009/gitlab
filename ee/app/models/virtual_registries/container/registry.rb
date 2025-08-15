# frozen_string_literal: true

module VirtualRegistries
  module Container
    class Registry < ApplicationRecord
      MAX_REGISTRY_COUNT = 5

      belongs_to :group

      has_many :registry_upstreams,
        -> { order(position: :asc) },
        class_name: 'VirtualRegistries::Container::RegistryUpstream',
        inverse_of: :registry
      has_many :upstreams,
        class_name: 'VirtualRegistries::Container::Upstream',
        through: :registry_upstreams
    end
  end
end
