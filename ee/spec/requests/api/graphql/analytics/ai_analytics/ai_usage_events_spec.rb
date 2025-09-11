# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Group|Project).aiUsageData.all', feature_category: :code_suggestions do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, name: 'my-group') }
  let_it_be(:subgroup) { create(:group, parent: group, name: 'my-subgroup') }
  let_it_be(:group_project) { create(:project, group: group) }
  let_it_be(:subgroup_project) { create(:project, group: group) }
  let_it_be(:other_group_project) { create(:project) }
  let_it_be(:current_user) { create(:user, :with_self_managed_duo_enterprise_seat, :with_namespace) }
  let_it_be(:user_1) { create(:user, :with_namespace) }
  let_it_be(:user_2) { create(:user, :with_namespace) }
  let_it_be(:user_3) { create(:user, :with_namespace) }

  let(:ai_usage_data_fields) do
    nodes = <<~NODES
      nodes {
        user {
          id
        }
        id
        event
        timestamp
      }
    NODES

    query_graphql_field(:aiUsageData, {}, query_graphql_field(:all, filter_params, nodes))
  end

  let(:filter_params) { { start_date: 3.days.ago, end_date: 3.days.since } }

  let_it_be(:code_suggestion_event_1) do
    create(:ai_usage_event, event: :code_suggestion_shown_in_ide, user: user_1,
      namespace: group_project.reload.project_namespace)
  end

  let_it_be(:code_suggestion_event_2) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_1,
      namespace: subgroup_project.reload.project_namespace)
  end

  let_it_be(:code_suggestion_event_3) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_2,
      namespace: other_group_project.reload.project_namespace)
  end

  let_it_be(:code_suggestion_event_4) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_3,
      namespace: subgroup_project.reload.project_namespace)
  end

  let_it_be(:out_of_timeframe_event) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_3,
      namespace: subgroup_project.reload.project_namespace, timestamp: 10.days.ago)
  end

  shared_examples 'common ai usage events field' do
    context 'when user cannot read usage events' do
      before_all do
        group.add_guest(current_user)
      end

      it 'returns no data' do
        post_graphql(query, current_user: current_user)

        expect(response_events).to be_nil
      end
    end

    context 'when user can read usage events' do
      before_all do
        group.add_reporter(current_user)
      end

      it 'returns events' do
        post_graphql(query, current_user: current_user)

        expect(response_events.pluck('id')).to match_array(expected_event_ids)
      end
    end
  end

  context 'for group' do
    it_behaves_like 'common ai usage events field' do
      let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_usage_data_fields) }
      let(:response_events) { graphql_data.dig('group', 'aiUsageData', 'all', 'nodes') }
      let(:expected_event_ids) do
        [
          code_suggestion_event_1,
          code_suggestion_event_2,
          code_suggestion_event_4
        ].map(&:to_global_id).map(&:to_s)
      end
    end
  end

  context 'for project' do
    it_behaves_like 'common ai usage events field' do
      let(:query) { graphql_query_for(:project, { fullPath: subgroup_project.full_path }, ai_usage_data_fields) }
      let(:response_events) { graphql_data.dig('project', 'aiUsageData', 'all', 'nodes') }
      let(:expected_event_ids) do
        [
          code_suggestion_event_2,
          code_suggestion_event_4
        ].map(&:to_global_id).map(&:to_s)
      end
    end
  end
end
