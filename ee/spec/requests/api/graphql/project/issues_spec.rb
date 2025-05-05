# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an issue list for a project', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group1) { create(:group, developers: current_user) }
  let_it_be(:project) { create(:project, group: group1) }
  let_it_be(:public_project) { project }
  let_it_be(:issue_a) { create(:issue, project: project) }
  let_it_be(:issue_b) { create(:issue, project: project, weight: 1) }
  let_it_be(:issue_c) { create(:issue, project: project, weight: 2) }
  let_it_be(:issue_d) { create(:issue, project: project, weight: 3) }
  let_it_be(:issue_e) { create(:issue, project: project, weight: 4) }

  let(:issue_filter_params) { {} }
  let(:issues) { [issue_a, issue_b, issue_c, issue_d, issue_e] }

  # All new specs should be added to the shared example if the change also
  # affects the `issues` query at the root level of the API.
  # Shared example also used in ee/spec/requests/api/graphql/issues_spec.rb
  it_behaves_like 'graphql issue list request spec EE' do
    let(:issue_nodes_path) { %w[project issues nodes] }

    # sorting
    let(:data_path) { [:project, :issues] }

    def pagination_query(params)
      graphql_query_for(
        :project,
        { full_path: project.full_path },
        query_nodes(:issues, :id, args: params, include_pagination_info: true)
      )
    end
  end

  def execute_query
    post_query
  end

  def post_query(request_user = current_user)
    post_graphql(query, current_user: request_user)
  end

  def query(params = issue_filter_params)
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('issues', params, fields)
    )
  end

  context 'when filtered by negated health status' do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:issue_at_risk) { create(:issue, health_status: :at_risk, project: project) }
    let_it_be(:issue_needs_attention) { create(:issue, health_status: :needs_attention, project: project) }

    let(:params) { { not: { health_status_filter: :atRisk } } }
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_nodes(:issues, :id, args: params)
      )
    end

    it 'only returns issues without the negated health status' do
      post_graphql(query, current_user: current_user)

      issues = graphql_data.dig('project', 'issues', 'nodes')

      expect(issues.size).to eq(1)
      expect(issues.first["id"]).to eq(issue_needs_attention.to_global_id.to_s)
    end
  end

  # Temporarily legacy issues need to be filterable by status for
  # the legacy issue list and legacy issue boards.
  context 'when filtered by status' do
    let_it_be(:issue_a_current_status) { create(:work_item_current_status, work_item_id: issue_a.id) }
    let_it_be(:issue_b_current_status) do
      create(:work_item_current_status, work_item_id: issue_b.id, system_defined_status_id: 2)
    end

    let(:status) { build(:work_item_system_defined_status) }
    let(:status_name) { 'to do' }
    let(:params) { { status: { id: status.to_global_id } } }
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_nodes(:issues, :id, args: params)
      )
    end

    shared_examples 'a filtered list' do
      it 'filters by status argument' do
        post_graphql(query, current_user: current_user)

        issues = graphql_data.dig('project', 'issues', 'nodes')

        expect(issues.size).to eq(1)
        expect(issues.first["id"]).to eq(issue_a.to_global_id.to_s)
      end
    end

    shared_examples 'an unfiltered list' do
      it 'does not filter by status argument' do
        post_graphql(query, current_user: current_user)

        issues = graphql_data.dig('project', 'issues', 'nodes')

        expect(issues.size).to eq(project.issues.count)
      end
    end

    it_behaves_like 'an unfiltered list'

    context 'when feature is licensed' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      context 'when filtering by status id' do
        it_behaves_like 'a filtered list'
      end

      context 'when filtering by status name' do
        let(:params) { { status: { name: status_name } } }

        it_behaves_like 'a filtered list'
      end

      context 'when filtering by both status_id and status_name' do
        let(:status_name) { 'in progress' }
        let(:params) { { status: { id: status.to_global_id, name: status_name } } }

        it 'returns an error' do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to contain_exactly(
            hash_including('message' => 'Only one of [id, name] arguments is allowed at the same time.')
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
  end
end
