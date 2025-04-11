# frozen_string_literal: true

module Authz
  class BaseRole < ApplicationRecord
    validate :ensure_at_least_one_permission_is_enabled

    before_destroy :prevent_delete_if_admin_user_associated, if: :admin_related_role?

    self.abstract_class = true

    def ensure_at_least_one_permission_is_enabled
      return if self.class.all_customizable_permissions.keys.any? { |attr| self[attr] }

      errors.add(:base, s_('MemberRole|Cannot create a member role with no enabled permissions'))
    end

    def prevent_delete_if_admin_user_associated
      return unless user_member_roles.present?

      errors.add(
        :base,
        s_(
          "MemberRole|Admin role is assigned to one or more users. " \
            "Remove role from all users, then delete role."
        )
      )

      # Stop the process of deletion in this callback. Otherwise,
      # deletion would proceed even if we make the object invalid.
      throw :abort # rubocop:disable Cop/BanCatchThrow -- See above.
    end
  end
end
