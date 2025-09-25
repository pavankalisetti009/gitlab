# frozen_string_literal: true

require "spec_helper"

RSpec.describe Subscriptions::Security::PoliciesSyncUpdated, feature_category: :security_policy_management do
  include GraphqlHelpers
  include ::Graphql::Subscriptions::Security::PoliciesSyncUpdated::Helper

  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace) }
  let_it_be(:security_policy_project) { policy_configuration.security_policy_management_project }
  let_it_be(:current_user) { security_policy_project.creator }

  let(:projects_progress) { 75.5 }
  let(:projects_total) { 100 }
  let(:failed_projects) { ["123"] }
  let(:merge_requests_progress) { 50 }
  let(:merge_requests_total) { 200 }
  let(:in_progress) { true }

  let(:subscribe) { security_policies_sync_updated_subscription(policy_configuration, current_user) }

  before do
    stub_licensed_features(security_orchestration_policies: true)

    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.security_policies_sync_updated(
        policy_configuration,
        projects_progress,
        projects_total,
        failed_projects,
        merge_requests_progress,
        merge_requests_total,
        in_progress)
    end
  end

  context 'when authorized' do
    subject(:success_response) do
      graphql_dig_at(graphql_data(response[:result]), :securityPoliciesSyncUpdated)
    end

    specify do
      expect(success_response).to eq({
        "projectsProgress" => projects_progress,
        "projectsTotal" => projects_total,
        "failedProjects" => failed_projects,
        "mergeRequestsProgress" => merge_requests_progress,
        "mergeRequestsTotal" => merge_requests_total,
        "inProgress" => in_progress
      })
    end
  end

  context 'when unauthorized' do
    let_it_be(:current_user) { create(:user) }

    it { is_expected.to be_nil }
  end
end
