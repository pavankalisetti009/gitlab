# frozen_string_literal: true

module Authz
  class UserGroupMemberRole < ApplicationRecord
    belongs_to :user
    belongs_to :group, class_name: '::Group'
    belongs_to :shared_with_group, class_name: '::Group'
    belongs_to :member_role

    validates :user, presence: true, uniqueness: { scope: %i[group_id shared_with_group_id member_role_id] }
    validates :group, presence: true
    validates :member_role, presence: true

    def self.for_user_in_group_and_shared_groups(user, group)
      where(user: user)
        .where('group_id = ? OR shared_with_group_id = ?', group.id, group.id)
    end
  end
end
