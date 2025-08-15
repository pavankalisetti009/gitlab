# frozen_string_literal: true

module VirtualRegistries
  module Container
    class Upstream < ApplicationRecord
      belongs_to :group

      has_many :registry_upstreams,
        class_name: 'VirtualRegistries::Container::RegistryUpstream',
        inverse_of: :upstream,
        autosave: true
      has_many :registries, class_name: 'VirtualRegistries::Container::Registry', through: :registry_upstreams

      encrypts :username, :password
    end
  end
end
