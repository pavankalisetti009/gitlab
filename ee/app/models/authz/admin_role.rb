# frozen_string_literal: true

module Authz
  class AdminRole < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    validates :permissions, json_schema: { filename: 'admin_role_permissions' }

    jsonb_accessor :permissions,
      Gitlab::CustomRoles::Definition.admin.keys.index_with(::Gitlab::Database::Type::JsonbBoolean.new)
  end
end
