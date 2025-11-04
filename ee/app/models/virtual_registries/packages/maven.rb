# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      def self.table_name_prefix
        'virtual_registries_packages_maven_'
      end

      def self.virtual_registry_available?(group, current_user, permission = :read_virtual_registry)
        group.dependency_proxy_feature_available? &&
          ::Feature.enabled?(:maven_virtual_registry, group) &&
          group.licensed_feature_available?(:packages_virtual_registry) &&
          Ability.allowed?(current_user, permission, group.virtual_registry_policy_subject) &&
          ::VirtualRegistries::Setting.find_for_group(group).enabled
      end
    end
  end
end
