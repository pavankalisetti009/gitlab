# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Npm
      class RegistryUpstream < ApplicationRecord
        # TODO: remove after making the class inherit from ::VirtualRegistries::RegistryUpstream
        # https://gitlab.com/gitlab-org/gitlab/-/work_items/581343
        belongs_to :group

        belongs_to :registry,
          class_name: '::VirtualRegistries::Packages::Npm::Registry',
          inverse_of: :registry_upstreams
        belongs_to :upstream,
          class_name: '::VirtualRegistries::Packages::Npm::Upstream',
          inverse_of: :registry_upstreams
      end
    end
  end
end
