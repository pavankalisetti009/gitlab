# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.instance_standard_role', feature_category: :system_access do
  include GraphqlHelpers

  def standard_roles_query
    <<~QUERY
    {
      standardRoles {
        nodes {
          accessLevel
          name
          membersCount
        }
      }
    }
    QUERY
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:member_1) { create(:group_member, :guest) }
  let_it_be(:member_2) { create(:group_member, :maintainer) }
  let_it_be(:member_3) { create(:project_member, :guest) }

  subject(:roles) do
    graphql_data.dig('standardRoles', 'nodes')
  end

  before do
    post_graphql(standard_roles_query, current_user: user)
  end

  context 'when on SaaS', :saas do
    it 'returns error' do
      expect_graphql_errors_to_include(
        'The feature is not available for SaaS.'
      )
    end
  end

  context 'when on self-managed' do
    it_behaves_like 'a working graphql query'

    it 'returns all standard-level roles with counts' do
      expected_result = [
        { 'accessLevel' => 5, 'name' => 'Minimal Access', 'membersCount' => 0 },
        { 'accessLevel' => 10, 'name' => 'Guest', 'membersCount' => 2 },
        { 'accessLevel' => 20, 'name' => 'Reporter', 'membersCount' => 0 },
        { 'accessLevel' => 30, 'name' => 'Developer', 'membersCount' => 0 },
        { 'accessLevel' => 40, 'name' => 'Maintainer', 'membersCount' => 1 },
        { 'accessLevel' => 50, 'name' => 'Owner', 'membersCount' => 1 } # one owner is created during project creation
      ]

      expect(roles).to eq(expected_result)
    end
  end
end
