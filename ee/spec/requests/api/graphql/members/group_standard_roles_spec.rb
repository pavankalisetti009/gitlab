# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.group_standard_role', feature_category: :system_access do
  include GraphqlHelpers

  def standard_roles_query
    <<~QUERY
    {
      group(fullPath: "#{group_1.full_path}") {
        standardRoles {
          nodes {
            accessLevel
            name
            membersCount
          }
        }
      }
    }
    QUERY
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:group_1) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group_1) }
  let_it_be(:project) { create(:project, group: group_1) }
  let_it_be(:group_2) { create(:group) }
  let_it_be(:member_1) { create(:group_member, :guest, group: group_1) }
  let_it_be(:member_g2) { create(:group_member, :developer, group: group_2) }
  let_it_be(:member_2) { create(:group_member, :maintainer, group: subgroup) }
  let_it_be(:member_3) { create(:project_member, :guest, project: project) }

  subject(:roles) do
    graphql_data.dig('group', 'standardRoles', 'nodes')
  end

  before do
    post_graphql(standard_roles_query, current_user: user)
  end

  it_behaves_like 'a working graphql query'

  it 'returns all standard-level roles with counts' do
    expected_result = [
      { 'accessLevel' => 5, 'name' => 'Minimal Access', 'membersCount' => 0 },
      { 'accessLevel' => 10, 'name' => 'Guest', 'membersCount' => 2 },
      { 'accessLevel' => 20, 'name' => 'Reporter', 'membersCount' => 0 },
      { 'accessLevel' => 30, 'name' => 'Developer', 'membersCount' => 0 },
      { 'accessLevel' => 40, 'name' => 'Maintainer', 'membersCount' => 1 },
      { 'accessLevel' => 50, 'name' => 'Owner', 'membersCount' => 0 }
    ]

    expect(roles).to eq(expected_result)
  end
end
