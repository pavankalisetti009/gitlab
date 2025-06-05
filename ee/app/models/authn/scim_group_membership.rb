# frozen_string_literal: true

module Authn
  class ScimGroupMembership < ApplicationRecord
    self.table_name = 'scim_group_memberships'

    belongs_to :user, optional: false

    validates :scim_group_uid, presence: true
    validates :user, uniqueness: { scope: :scim_group_uid }
  end
end
