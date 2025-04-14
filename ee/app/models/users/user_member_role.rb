# frozen_string_literal: true

module Users
  class UserMemberRole < ApplicationRecord
    self.table_name = 'user_member_roles'

    belongs_to :member_role
    belongs_to :user

    validates :member_role, presence: true
    validates :user, presence: true, uniqueness: true

    def self.create_or_update(user:, member_role:)
      find_or_initialize_by(user: user).tap do |record|
        record.update(member_role: member_role)
      end
    end
  end
end
