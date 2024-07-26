# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting organization information', feature_category: :cell do
  include ::GraphqlHelpers

  let(:query) { graphql_query_for(:organization, { id: organization.to_global_id }, organization_fields) }
  let(:current_user) { user }

  let_it_be(:organization_owner) { create(:organization_owner) }
  let_it_be(:organization) { organization_owner.organization }
  let_it_be(:user) { organization_owner.user }
  let_it_be(:project) { create(:project, organization: organization, developers: user) }

  let_it_be(:saml_group) do
    saml_provider = create(:saml_provider)
    create(:group, organization: organization, saml_provider: saml_provider, developers: user) do |group|
      create(:group_saml_identity, saml_provider: group.saml_provider, user: user)
    end
  end

  let_it_be(:saml_project) { create(:project, group: saml_group, organization: organization, developers: user) }

  subject(:request_organization) { post_graphql(query, current_user: current_user) }

  context 'when requesting projects' do
    let(:projects) { graphql_data_at(:organization, :projects, :nodes) }
    let(:organization_fields) do
      <<~FIELDS
        projects(first: 1) {
          nodes {
            id
          }
        }
      FIELDS
    end

    context 'when current user has an active SAML session' do
      before do
        active_saml_sessions = { saml_group.saml_provider.id => Time.current }
        allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)
      end

      it 'includes SAML project' do
        request_organization

        expect(projects).to match_array(a_graphql_entity_for(saml_project))
      end
    end

    context 'when current user has no active SAML session' do
      it 'excludes SAML project' do
        request_organization

        expect(projects).to match_array(a_graphql_entity_for(project))
      end
    end
  end
end
