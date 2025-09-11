# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying work item allowed statuses', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group_1) { create(:group) }
  let_it_be(:group_2) { create(:group) }

  let_it_be(:to_do_status_1) { create(:work_item_custom_status, :to_do, name: 'To Do', namespace: group_1) }
  let_it_be(:to_do_status_2) { create(:work_item_custom_status, :to_do, name: 'To Do', namespace: group_2) }

  let(:query) do
    <<~QUERY
    query {
      workItemAllowedStatuses {
        nodes {
          id
          name
          iconName
          color
          category
        }
      }
    }
    QUERY
  end

  it 'returns an empty array' do
    post_graphql(query, current_user: user)

    expect(response).to have_gitlab_http_status(:ok)
    expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to eq([])
  end

  context 'when filtering by name' do
    let(:query) do
      <<~QUERY
      query {
        workItemAllowedStatuses(name: "To Do") {
          nodes {
            id
            name
          }
        }
      }
      QUERY
    end

    it 'returns an empty array' do
      post_graphql(query, current_user: user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:work_item_allowed_statuses, :nodes)).to eq([])
    end
  end
end
