# frozen_string_literal: true

module Authz
  class BaseRole < ApplicationRecord
    include Authz::AdminRollable

    validate :validate_permissions

    self.abstract_class = true

    class << self
      def permission_enabled?(permission, user)
        return true unless ::Feature::Definition.get("custom_ability_#{permission}")

        ## this feature flag name 'pattern' is used for all custom roles so we can't
        ## avoid dynamically passing in the name to Feature.*abled?
        ::Feature.enabled?("custom_ability_#{permission}", user) # rubocop:disable FeatureFlagKeyDynamic -- see above
      end
    end

    def ensure_at_least_one_permission_is_enabled
      return if self.class.all_customizable_permissions.keys.any? { |attr| self[attr] }

      errors.add(:base, s_('MemberRole|Cannot create a member role with no enabled permissions'))
    end

    def enabled_permissions(user)
      self.class.all_customizable_permissions.filter do |permission|
        attributes[permission.to_s] && self.class.permission_enabled?(permission, user)
      end
    end

    def validate_permissions
      self.permissions = permissions.select { |_, enabled| enabled }

      if permissions.empty?
        errors.add(:base, s_('MemberRole|Cannot create a member role with no enabled permissions'))
        return
      end

      available_permissions = if admin_related_role?
                                self.class.all_customizable_admin_permissions
                              else
                                self.class.all_customizable_standard_permissions
                              end

      permissions.each_key do |permission|
        next if available_permissions.include?(permission.to_sym)

        message = format(s_('MemberRole|Unknown permission: %{permission}'), permission: permission)
        errors.add(:base, message)
      end
    end
  end
end
