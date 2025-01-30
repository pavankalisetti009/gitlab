# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting starredProjects of the user', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:path) { %i[user starred_projects nodes] }
  let_it_be(:user_params) { { username: current_user.username } }
  let_it_be(:user_fields) { 'starredProjects { nodes { id } }' }
  let_it_be(:query) do
    graphql_query_for(:user, user_params, user_fields)
  end

  it_behaves_like 'projects graphql query with SAML session filtering' do
    before do
      current_user.toggle_star(saml_project)
    end
  end
end
