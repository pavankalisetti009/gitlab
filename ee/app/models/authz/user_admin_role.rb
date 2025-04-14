# frozen_string_literal: true

module Authz
  class UserAdminRole < ApplicationRecord
    self.primary_key = 'user_id'

    belongs_to :user
    belongs_to :admin_role, class_name: 'Authz::AdminRole'

    # Quack like a UserMemberRole
    belongs_to :member_role, -> {
      readonly
    }, foreign_key: 'admin_role_id', class_name: 'Authz::AdminRole', inverse_of: :user_admin_roles

    validates :admin_role, presence: true
    validates :user, presence: true, uniqueness: true

    def self.klass(user)
      if Feature.enabled?(:extract_admin_roles_from_member_roles, user)
        Authz::UserAdminRole
      else
        Users::UserMemberRole
      end
    end
  end
end
