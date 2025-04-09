# frozen_string_literal: true

module Authz
  class AdminRole < ApplicationRecord
    has_many :user_admin_roles, class_name: 'Authz::UserAdminRole'
    has_many :users, through: :user_admin_roles

    validates :name, presence: true, uniqueness: true
    validates :permissions, json_schema: { filename: 'admin_role_permissions' }

    jsonb_accessor :permissions,
      Gitlab::CustomRoles::Definition.admin.keys.index_with(::Gitlab::Database::Type::JsonbBoolean.new)
  end
end
