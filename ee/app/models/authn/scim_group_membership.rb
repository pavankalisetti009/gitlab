# frozen_string_literal: true

module Authn
  class ScimGroupMembership < ApplicationRecord
    include BulkInsertSafe

    self.table_name = 'scim_group_memberships'

    belongs_to :user, optional: false

    validates :scim_group_uid, presence: true
    validates :user, uniqueness: { scope: :scim_group_uid }

    scope :by_scim_group_uid, ->(scim_group_uid) { where(scim_group_uid: scim_group_uid) }
    scope :by_user_id, ->(user_id) { where(user_id: user_id) }
  end
end
