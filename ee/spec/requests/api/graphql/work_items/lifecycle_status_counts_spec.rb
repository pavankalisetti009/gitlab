# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query lifecycle status counts', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:subgroup_project) { create(:project, group: subgroup) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }

  let_it_be(:issue_work_item_type) { create(:work_item_type, :issue) }
  let_it_be(:task_work_item_type) { create(:work_item_type, :task) }

  let_it_be(:work_item_1) { create(:work_item, :issue, project: project) }
  let_it_be(:work_item_2) { create(:work_item, :issue, project: subgroup_project) }
  let_it_be(:work_item_3) { create(:work_item, :task, project: subgroup_project) }
  let_it_be(:work_item_4) { create(:work_item, :task, :closed, project: project) }
  let_it_be(:work_item_5) { create(:work_item, :task, :closed, project: subgroup_project) }

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

  shared_examples 'a work item status counter with overflow handling' do
    context 'when there are more work items than the maximum countable limit' do
      before do
        stub_const('Resolvers::WorkItems::Lifecycles::StatusCountsResolver::MAX_COUNTABLE_WORK_ITEMS', 1)
      end

      it 'returns counts with "+" suffix when exceeding the maximum' do
        post_graphql(query, current_user: current_user, variables: variables)

        expect(graphql_data.dig('namespace', 'lifecycles', 'nodes')).to include(
          a_hash_including(
            'statusCounts' => include(
              a_hash_including(
                'status' => a_hash_including('id' => lifecycle.default_open_status.to_gid.to_s),
                'count' => "1+"
              )
            )
          )
        )
      end
    end
  end

  context 'when user has access' do
    context 'with system-defined lifecycles' do
      let_it_be(:lifecycle) { build(:work_item_system_defined_lifecycle) }
      let_it_be(:system_defined_in_progress) { build(:work_item_system_defined_status, :in_progress) }
      let_it_be(:system_defined_wont_do) { build(:work_item_system_defined_status, :wont_do) }

      it 'returns status counts' do
        post_graphql(query, current_user: current_user, variables: variables)

        expect(graphql_data.dig('namespace', 'lifecycles', 'nodes')).to include(
          'id' => lifecycle.to_gid.to_s,
          'statusCounts' => match_array([
            {
              'status' => {
                'id' => lifecycle.default_open_status.to_gid.to_s
              },
              'count' => "3"
            },
            {
              'status' => {
                'id' => system_defined_in_progress.to_gid.to_s
              },
              'count' => "0"
            },
            {
              'status' => {
                'id' => lifecycle.default_closed_status.to_gid.to_s
              },
              'count' => "2"
            },
            {
              'status' => {
                'id' => system_defined_wont_do.to_gid.to_s
              },
              'count' => "0"
            },
            {
              'status' => {
                'id' => lifecycle.default_duplicate_status.to_gid.to_s
              },
              'count' => "0"
            }
          ])
        )
      end

      it_behaves_like 'a work item status counter with overflow handling'
    end

    context 'with custom lifecycles' do
      let_it_be(:lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }

      context 'when lifecycle is not in use' do
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

      context 'when lifecycle is in use' do
        let!(:issue_type_custom_lifecycle) do
          create(:work_item_type_custom_lifecycle,
            work_item_type: issue_work_item_type,
            lifecycle: lifecycle,
            namespace: group
          )
        end

        let!(:task_type_custom_lifecycle) do
          create(:work_item_type_custom_lifecycle,
            work_item_type: task_work_item_type,
            lifecycle: lifecycle,
            namespace: group
          )
        end

        it 'returns status counts' do
          post_graphql(query, current_user: current_user, variables: variables)

          expect(graphql_data.dig('namespace', 'lifecycles', 'nodes')).to include(
            'id' => lifecycle.to_gid.to_s,
            'statusCounts' => match_array([
              {
                'status' => {
                  'id' => lifecycle.default_open_status.to_gid.to_s
                },
                'count' => "3"
              },
              {
                'status' => {
                  'id' => lifecycle.default_closed_status.to_gid.to_s
                },
                'count' => "2"
              },
              {
                'status' => {
                  'id' => lifecycle.default_duplicate_status.to_gid.to_s
                },
                'count' => "0"
              }
            ])
          )
        end

        it_behaves_like 'a work item status counter with overflow handling'
      end
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
