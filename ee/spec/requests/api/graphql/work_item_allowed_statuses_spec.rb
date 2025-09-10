# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying work item allowed statuses', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }

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
end
