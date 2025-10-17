# frozen_string_literal: true

module Authz
  class BaseRole < ApplicationRecord
    include Authz::AdminRollable

    validate :validate_permissions

    self.abstract_class = true

    class << self
      def permission_enabled?(permission)
        return true unless ::Feature::Definition.get("custom_ability_#{permission}")

        ## this feature flag name 'pattern' is used for all custom roles so we can't
        ## avoid dynamically passing in the name to Feature.*abled?
        ::Feature.enabled?("custom_ability_#{permission}", :instance) # rubocop:disable FeatureFlagKeyDynamic -- see above
      end
    end

    def enabled_permissions
      self.class.all_customizable_permissions.filter do |permission|
        attributes[permission.to_s] && self.class.permission_enabled?(permission)
      end
    end

    private

    def validate_permissions
      self.permissions = permissions.select { |_, enabled| enabled }

      if permissions.empty?
        errors.add(:base, s_('MemberRole|Cannot create a member role with no enabled permissions'))
        return
      end

      allowed_permissions = available_permissions
      permissions.each_key do |permission|
        next if allowed_permissions.include?(permission.to_sym)

        message = format(s_('MemberRole|Unknown permission: %{permission}'), permission: permission)
        errors.add(:base, message)
      end
    end

    def available_permissions
      available = if admin_related_role?
                    self.class.all_customizable_admin_permissions
                  else
                    self.class.all_customizable_standard_permissions
                  end

      available.select { |permission| self.class.permission_enabled?(permission) }
    end
  end
end
