# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query LDAP admin links', feature_category: :permissions do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }

  let_it_be(:admin_member_role) { create(:member_role, :admin, name: 'Admin role') }
  let_it_be(:ldap_admin_link) { create(:ldap_admin_role_link, member_role: admin_member_role) }

  let(:arguments) { {} }
  let(:current_user) { admin }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id
        provider
        filter
        cn
        adminMemberRole {
          name
        }
      }
    GRAPHQL
  end

  let(:query) do
    graphql_query_for('ldap_admin_role_links', arguments, fields)
  end

  subject(:ldap_admin_role_links) { graphql_data['ldapAdminRoleLinks'] }

  context 'when custom roles licensed feature is available' do
    before do
      stub_licensed_features(custom_roles: true)

      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a working graphql query'

    it 'returns all ldap admin links' do
      expect(ldap_admin_role_links['nodes']).to eq([{
        'id' => ldap_admin_link.to_global_id.to_s,
        'provider' => 'ldapmain',
        'filter' => nil,
        'cn' => 'group1',
        'adminMemberRole' => { 'name' => 'Admin role' }
      }])
    end
  end

  context 'when custom roles licensed feature is unavailable' do
    before do
      stub_licensed_features(custom_roles: false)

      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when `custom_admin_roles` feature-flag is disabled' do
    before do
      stub_feature_flags(custom_admin_roles: false)

      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is not admin' do
    let(:current_user) { create(:user) }

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end
end
