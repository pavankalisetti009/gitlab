# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Status filters', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:group_label) { create(:group_label, group: group) }
  let(:board) { create(:board, resource_parent: resource_parent) }
  let(:label_list) { create(:list, board: board, label: group_label) }

  let_it_be(:work_item_1) { create(:work_item, :issue, project: project, labels: [group_label]) }
  let_it_be(:work_item_2) { create(:work_item, :task, project: project, labels: [group_label]) }
  let_it_be(:work_item_3) { create(:work_item, :task, project: project, labels: [group_label]) }

  let_it_be(:current_status_1) { create(:work_item_current_status, work_item: work_item_1) }
  let_it_be(:current_status_2) { create(:work_item_current_status, work_item: work_item_2) }

  let_it_be(:status_id) { ::WorkItems::Statuses::SystemDefined::Status.find(1).to_global_id }
  let_it_be(:status_name) { 'to do' }

  let(:current_user) { create(:user, guest_of: group) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'a filtered list' do
    it 'filters by status argument' do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(2)
      expect(model_ids).to contain_exactly(work_item_1.id, work_item_2.id)
    end
  end

  shared_examples 'an unfiltered list' do
    it 'does not filter by status argument' do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(3)
      expect(model_ids).to contain_exactly(work_item_1.id, work_item_2.id, work_item_3.id)
    end
  end

  shared_examples 'supports filtering by status ID' do
    let(:params) { { status: { id: status_id } } }

    context 'when filtering by valid ID' do
      it_behaves_like 'a filtered list'
    end

    context 'when filtering by invalid ID' do
      let(:params) { { status: { id: "gid://gitlab/WorkItems::Statuses::SystemDefined::Status/999" } } }

      it 'returns an error' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to contain_exactly(
          hash_including('message' => "System-defined status doesn't exist.")
        )
      end
    end

    context 'when work_item_status_feature_flag feature flag is disabled' do
      before do
        stub_feature_flags(work_item_status_feature_flag: false)
      end

      it_behaves_like 'an unfiltered list'
    end
  end

  shared_examples 'supports filtering by status name' do
    let(:params) { { status: { name: status_name } } }

    context 'when filtering by valid name' do
      it_behaves_like 'a filtered list'
    end

    context 'when filtering by invalid name' do
      let(:params) { { status: { name: 'invalid' } } }

      it_behaves_like 'an unfiltered list'
    end

    context 'when work_item_status_feature_flag feature flag is disabled' do
      before do
        stub_feature_flags(work_item_status_feature_flag: false)
      end

      it_behaves_like 'an unfiltered list'
    end
  end

  shared_examples 'does not support filtering by both status ID and name' do
    let(:params) { { status: { id: status_id, name: status_name } } }

    it 'returns an error' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to contain_exactly(
        hash_including('message' => 'Only one of [id, name] arguments is allowed at the same time.')
      )
    end
  end

  context 'when querying group.board.lists.issues' do
    let_it_be(:resource_parent) { group }

    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path },
        <<~BOARDS
          boards(first: 1) {
            nodes {
              lists(id: "#{label_list.to_global_id}") {
                nodes {
                  issues(#{attributes_to_graphql(filters: params)}) {
                    nodes {
                      id
                    }
                  }
                }
              }
            }
          }
        BOARDS
      )
    end

    let(:items) do
      graphql_data.dig('group', 'boards', 'nodes')[0]
        .dig('lists', 'nodes')[0]
        .dig('issues', 'nodes')
    end

    it_behaves_like 'supports filtering by status ID'
    it_behaves_like 'supports filtering by status name'
    it_behaves_like 'does not support filtering by both status ID and name'
  end

  context 'when querying project.board.lists.issues' do
    let_it_be(:resource_parent) { project }

    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        <<~BOARDS
          boards(first: 1) {
            nodes {
              lists(id: "#{label_list.to_global_id}") {
                nodes {
                  issues(#{attributes_to_graphql(filters: params)}) {
                    nodes {
                      id
                    }
                  }
                }
              }
            }
          }
        BOARDS
      )
    end

    let(:items) do
      graphql_data.dig('project', 'boards', 'nodes')[0]
        .dig('lists', 'nodes')[0]
        .dig('issues', 'nodes')
    end

    it_behaves_like 'supports filtering by status ID'
    it_behaves_like 'supports filtering by status name'
    it_behaves_like 'does not support filtering by both status ID and name'
  end
end
