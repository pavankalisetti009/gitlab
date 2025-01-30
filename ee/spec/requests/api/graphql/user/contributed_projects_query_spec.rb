# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting contributedProjects of the user', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:user_params) { { username: current_user.username } }
  let_it_be(:user_fields) { 'contributedProjects { nodes { id } }' }
  let_it_be(:query) { graphql_query_for(:user, user_params, user_fields) }
  let_it_be(:path) { %i[user contributed_projects nodes] }

  it_behaves_like 'projects graphql query with SAML session filtering' do
    before do
      travel_to(4.hours.from_now) { create(:push_event, project: saml_project, author: current_user) }
    end
  end
end
