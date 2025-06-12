# frozen_string_literal: true

module Authn
  class ScimGroupMembership < ApplicationRecord
    self.table_name = 'scim_group_memberships'

    belongs_to :user, optional: false

    validates :scim_group_uid, presence: true
    validates :user, uniqueness: { scope: :scim_group_uid }

    scope :by_scim_group_uid, ->(scim_group_uid) { where(scim_group_uid: scim_group_uid) }
  end
end
