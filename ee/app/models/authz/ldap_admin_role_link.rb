# frozen_string_literal: true

module Authz
  class LdapAdminRoleLink < ApplicationRecord
    include NullifyIfBlank

    self.table_name = 'ldap_admin_role_links'

    belongs_to :member_role

    validates :member_role, :provider, presence: true
    validates :provider, :cn, :filter, length: { maximum: 255 }

    with_options if: :cn do
      validates :cn, uniqueness: { scope: [:provider] }
      validates :cn, presence: true
      validates :filter, absence: { message: _('One and only one of [cn, filter] arguments is required') }
    end

    with_options if: :filter do
      validates :filter, uniqueness: { scope: [:provider] }
      validates :filter, ldap_filter: true, presence: true
    end

    nullify_if_blank :cn, :filter
  end
end
