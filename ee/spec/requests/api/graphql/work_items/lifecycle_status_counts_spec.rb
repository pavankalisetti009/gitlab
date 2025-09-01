# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query lifecycle status counts', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }

  let(:current_user) { maintainer }

  let(:query) do
    <<~GRAPHQL
      query {
        namespace(fullPath: "#{group.full_path}") {
          id
          lifecycles {
            nodes {
              id
              statusCounts {
                status {
                  id
                }
                count
              }
            }
          }
        }
      }
    GRAPHQL
  end

  let(:variables) { { fullPath: group.to_gid.to_s } }

  before do
    stub_licensed_features(work_item_status: true)
  end

  context 'when user has access' do
    it 'returns status counts with null values' do
      post_graphql(query, current_user: current_user, variables: variables)

      expect(graphql_data.dig('namespace', 'lifecycles', 'nodes')).to include(
        'id' => lifecycle.to_gid.to_s,
        'statusCounts' => match_array([
          {
            'status' => {
              'id' => lifecycle.default_open_status.to_gid.to_s
            },
            'count' => nil
          },
          {
            'status' => {
              'id' => lifecycle.default_closed_status.to_gid.to_s
            },
            'count' => nil
          },
          {
            'status' => {
              'id' => lifecycle.default_duplicate_status.to_gid.to_s
            },
            'count' => nil
          }
        ])
      )
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(work_item_status: false)
    end

    it 'returns null' do
      post_graphql(query, current_user: current_user, variables: variables)

      expect(graphql_data.dig('namespace', 'lifecycles')).to be_nil
    end
  end
end
