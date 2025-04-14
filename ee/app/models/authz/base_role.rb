# frozen_string_literal: true

module Authz
  class BaseRole < ApplicationRecord
    include Authz::AdminRollable

    validate :ensure_at_least_one_permission_is_enabled

    self.abstract_class = true

    def ensure_at_least_one_permission_is_enabled
      return if self.class.all_customizable_permissions.keys.any? { |attr| self[attr] }

      errors.add(:base, s_('MemberRole|Cannot create a member role with no enabled permissions'))
    end
  end
end
