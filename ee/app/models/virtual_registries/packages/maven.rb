# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      def self.table_name_prefix
        'virtual_registries_packages_maven_'
      end

      def self.feature_enabled?(group)
        group.dependency_proxy_feature_available? &&
          ::Feature.enabled?(:maven_virtual_registry, group) &&
          group.licensed_feature_available?(:packages_virtual_registry) &&
          ::VirtualRegistries::Setting.find_for_group(group).enabled
      end

      def self.user_has_access?(group, current_user, permission = :read_virtual_registry)
        has_access = Ability.allowed?(current_user, permission, group.virtual_registry_policy_subject)

        log_access_through_project_membership(group, current_user) if has_access && permission == :read_virtual_registry

        has_access
      end

      def self.virtual_registry_available?(group, current_user, permission = :read_virtual_registry)
        feature_enabled?(group) && user_has_access?(group, current_user, permission)
      end

      # TODO: Remove logging after access through project membership is removed
      # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/587915
      def self.log_access_through_project_membership(group, current_user)
        return unless current_user

        policy = ::Ability.policy_for(current_user, group.virtual_registry_policy_subject)

        return unless policy.runners[:read_virtual_registry]&.steps&.detect(&:pass?)&.rule&.repr == 'group.has_projects'
        return if caller(1, 5).any? { |line| line.include?('virtual_registry_menu_item') }

        Gitlab::AppLogger.info(
          message: 'User granted read_virtual_registry access through project membership',
          user_id: current_user.id,
          group_id: group.id
        )
      end
    end
  end
end
