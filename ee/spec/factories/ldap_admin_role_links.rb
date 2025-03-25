# frozen_string_literal: true

FactoryBot.define do
  factory :ldap_admin_role_link, class: 'Authz::LdapAdminRoleLink' do
    member_role { association(:member_role) }
    provider { 'ldapmain' }
    cn { 'group1' }
  end
end
