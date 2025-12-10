# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Npm
      class Registry < ApplicationRecord
        # TODO: remove after making the class inherit from ::VirtualRegistries::Registry
        # https://gitlab.com/gitlab-org/gitlab/-/work_items/581343
        belongs_to :group
        has_many :registry_upstreams,
          -> { order(position: :asc) },
          class_name: 'VirtualRegistries::Packages::Npm::RegistryUpstream',
          inverse_of: :registry
        has_many :upstreams,
          class_name: 'VirtualRegistries::Packages::Npm::Upstream',
          through: :registry_upstreams
      end
    end
  end
end
