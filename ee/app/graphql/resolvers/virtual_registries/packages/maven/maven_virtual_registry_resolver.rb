# frozen_string_literal: true

module Resolvers
  module VirtualRegistries
    module Packages
      module Maven
        class MavenVirtualRegistryResolver < BaseResolver
          type EE::Types::VirtualRegistries::Packages::Maven::MavenVirtualRegistryType, null: true

          alias_method :group, :object

          def resolve
            ::VirtualRegistries::Packages::Maven::Registry.for_group(group)
          end
        end
      end
    end
  end
end
