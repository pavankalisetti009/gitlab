# frozen_string_literal: true

module Authz
  class UserAdminRole < ApplicationRecord
    self.primary_key = 'user_id'

    belongs_to :user
    belongs_to :admin_role, class_name: 'Authz::AdminRole'

    validates :admin_role, presence: true
    validates :user, presence: true, uniqueness: true
  end
end
