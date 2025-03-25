# frozen_string_literal: true

module Authz
  class LdapAdminRoleLink < ApplicationRecord
    self.table_name = 'ldap_admin_role_links'

    belongs_to :member_role

    validates :member_role, :provider, presence: true
    validates :provider, :cn, :filter, length: { maximum: 255 }
  end
end
