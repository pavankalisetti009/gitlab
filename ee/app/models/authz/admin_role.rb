# frozen_string_literal: true

module Authz
  class AdminRole < Authz::BaseRole
    has_many :user_admin_roles, class_name: 'Authz::UserAdminRole'
    has_many :users, through: :user_admin_roles

    validates :name, presence: true, uniqueness: true
    validates :permissions, json_schema: { filename: 'admin_role_permissions' }

    alias_attribute :user_member_roles, :user_admin_roles

    jsonb_accessor :permissions,
      Gitlab::CustomRoles::Definition.admin.keys.index_with(::Gitlab::Database::Type::JsonbBoolean.new)

    def self.all_customizable_permissions
      Gitlab::CustomRoles::Definition.admin
    end

    def admin_related_role?
      true
    end
  end
end
