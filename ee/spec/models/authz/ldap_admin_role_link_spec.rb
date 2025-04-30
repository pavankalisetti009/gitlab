# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::LdapAdminRoleLink, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:member_role) }
  end

  describe 'validation' do
    subject(:ldap_admin_role_link) { build(:ldap_admin_role_link) }

    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_length_of(:provider).is_at_most(255) }
    it { is_expected.to validate_length_of(:cn).is_at_most(255) }
    it { is_expected.to validate_length_of(:filter).is_at_most(255) }

    it { is_expected.to nullify_if_blank(:cn) }
    it { is_expected.to nullify_if_blank(:filter) }

    describe 'cn' do
      context 'when cn is duplicated for the same provider' do
        before do
          create(:ldap_admin_role_link, cn: 'cn', provider: 'ldapmain')
        end

        it 'returns an error' do
          duplicate_admin_link = build(:ldap_admin_role_link, cn: 'cn', provider: 'ldapmain')

          expect(duplicate_admin_link).not_to be_valid
          expect(duplicate_admin_link.errors.messages).to eq(cn: ['has already been taken'])
        end
      end

      context 'when filter is also provided' do
        it 'returns an error' do
          admin_link = build(:ldap_admin_role_link, cn: 'cn', filter: '(a=b)')

          expect(admin_link).not_to be_valid
          expect(admin_link.errors.messages).to eq(filter: ['One and only one of [cn, filter] arguments is required'])
        end
      end
    end

    describe 'filter' do
      context 'when filter is duplicated for the same provider' do
        before do
          create(:ldap_admin_role_link, cn: nil, filter: '(a=b)', provider: 'ldapmain')
        end

        it 'returns an error' do
          duplicate_admin_link = build(:ldap_admin_role_link, cn: nil, filter: '(a=b)', provider: 'ldapmain')

          expect(duplicate_admin_link).not_to be_valid
          expect(duplicate_admin_link.errors.messages).to eq(filter: ["has already been taken"])
        end
      end

      context 'when invalid filter is provided' do
        it 'returns an error' do
          admin_link = build(:ldap_admin_role_link, cn: nil, filter: 'invalid filter')

          expect(admin_link).not_to be_valid
          expect(admin_link.errors.messages).to eq(filter: ['must be a valid filter'])
        end
      end
    end
  end

  describe 'scopes' do
    describe '.with_provider' do
      it 'returns ldap admin role links for the specified provider' do
        links = [create(:ldap_admin_role_link, provider: 'ldapmain'),
          create(:ldap_admin_role_link, provider: 'ldapother')]

        expect(described_class.with_provider('ldapmain')).to eq([links.first])
      end
    end
  end
end
