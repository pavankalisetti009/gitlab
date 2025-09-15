# frozen_string_literal: true

module VirtualRegistries
  module Container
    class Upstream < ::VirtualRegistries::Upstream
      has_many :registry_upstreams,
        class_name: '::VirtualRegistries::Container::RegistryUpstream',
        inverse_of: :upstream,
        autosave: true
      has_many :registries, class_name: '::VirtualRegistries::Container::Registry', through: :registry_upstreams

      encrypts :username, :password

      validates :username, presence: true, if: :password?
      validates :password, presence: true, if: :username?
      validates :username, :password, length: { maximum: 510 }

      prevent_from_serialization(:password)
    end
  end
end
