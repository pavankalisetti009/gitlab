# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Npm
      class Upstream < ApplicationRecord
        # TODO: remove after making the class inherit from ::VirtualRegistries::Upstream
        # https://gitlab.com/gitlab-org/gitlab/-/work_items/581343
        belongs_to :group

        has_many :registry_upstreams,
          class_name: 'VirtualRegistries::Packages::Npm::RegistryUpstream',
          inverse_of: :upstream,
          autosave: true
        has_many :registries, class_name: 'VirtualRegistries::Packages::Npm::Registry', through: :registry_upstreams

        encrypts :username, :password
      end
    end
  end
end
