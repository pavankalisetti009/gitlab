# frozen_string_literal: true

module VirtualRegistries
  module Container
    def self.table_name_prefix
      'virtual_registries_container_'
    end

    def self.feature_enabled?(group)
      group.dependency_proxy_feature_available? &&
        ::Feature.enabled?(:container_virtual_registries, group) &&
        group.licensed_feature_available?(:container_virtual_registry) &&
        ::VirtualRegistries::Setting.find_for_group(group).enabled
    end

    def self.user_has_access?(group, current_user, permission = :read_virtual_registry)
      Ability.allowed?(current_user, permission, group.virtual_registry_policy_subject)
    end
  end
end
