# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'querying security policy sync status', feature_category: :security_policy_management do
  include GraphqlHelpers

  include_context 'with policy sync state'

  let_it_be(:current_user) { policy_configuration.security_policy_management_project.owner }

  let(:query) do
    <<~QUERY
    query {
      securityPoliciesSyncStatus(policyConfigurationId: "#{policy_configuration.to_global_id}") {
        projectsProgress
        projectsTotal
        failedProjects
        mergeRequestsProgress
        mergeRequestsTotal
        inProgress
      }
    }
    QUERY
  end

  before do
    policy_configuration.security_policy_management_project.add_maintainer(current_user)

    stub_licensed_features(security_orchestration_policies: true)
  end

  subject(:graphql_response) do
    graphql_data.fetch("securityPoliciesSyncStatus")&.transform_keys(&:underscore)&.symbolize_keys
  end

  context 'without sync' do
    specify do
      post_graphql(query, current_user: current_user)

      expect(graphql_response).to eq(
        projects_progress: 0.0,
        projects_total: 0,
        failed_projects: [],
        merge_requests_progress: 0.0,
        merge_requests_total: 0,
        in_progress: false
      )
    end
  end

  context 'with ongoing sync' do
    before do
      state.start_sync

      state.append_projects([1, 2, 3, 4])

      state.finish_project(1)
      state.fail_project(2)

      state.start_merge_request(1)
      state.start_merge_request(2)

      state.start_merge_request_worker(1)
      state.finish_merge_request_worker(1)
    end

    specify do
      post_graphql(query, current_user: current_user)

      expect(graphql_response).to eq(
        projects_progress: 50.0,
        projects_total: 4,
        failed_projects: %w[2],
        merge_requests_progress: 50.0,
        merge_requests_total: 2,
        in_progress: true
      )
    end
  end

  context 'with completed sync' do
    before do
      state.start_sync

      state.append_projects([1, 2])

      state.start_merge_request(1)
      state.start_merge_request(2)

      state.start_merge_request_worker(1)
      state.finish_merge_request_worker(1)

      state.start_merge_request_worker(2)
      state.finish_merge_request_worker(2)

      state.finish_project(1)
      state.fail_project(2)

      state.finish_sync
    end

    specify do
      post_graphql(query, current_user: current_user)

      expect(graphql_response).to eq(
        projects_progress: 100.0,
        projects_total: 2,
        failed_projects: %w[2],
        merge_requests_progress: 100.0,
        merge_requests_total: 2,
        in_progress: false
      )
    end
  end

  context 'when unauthorized' do
    let_it_be(:current_user) { create(:user) }

    before do
      post_graphql(query, current_user: current_user)
    end

    it { is_expected.to be_nil }
  end

  context 'with feature disabled' do
    before do
      stub_feature_flags(security_policy_sync_propagation_tracking: false)

      post_graphql(query, current_user: current_user)
    end

    it { is_expected.to be_nil }
  end
end
