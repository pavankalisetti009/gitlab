# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Group'], feature_category: :groups_and_projects do
  describe 'nested epic request' do
    it { expect(described_class).to have_graphql_field(:epicsEnabled) }
    it { expect(described_class).to have_graphql_field(:epic) }
    it { expect(described_class).to have_graphql_field(:epics) }
    it { expect(described_class).to have_graphql_field(:epic_board) }
    it { expect(described_class).to have_graphql_field(:epic_boards) }
  end

  it { expect(described_class).to have_graphql_field(:iterations) }
  it { expect(described_class).to have_graphql_field(:iteration_cadences) }
  it { expect(described_class).to have_graphql_field(:vulnerabilities) }
  it { expect(described_class).to have_graphql_field(:vulnerability_scanners) }
  it { expect(described_class).to have_graphql_field(:vulnerabilities_count_by_day) }
  it { expect(described_class).to have_graphql_field(:vulnerability_grades) }
  it { expect(described_class).to have_graphql_field(:code_coverage_activities) }
  it { expect(described_class).to have_graphql_field(:stats) }
  it { expect(described_class).to have_graphql_field(:billable_members_count) }
  it { expect(described_class).to have_graphql_field(:external_audit_event_destinations) }
  it { expect(described_class).to have_graphql_field(:external_audit_event_streaming_destinations) }
  it { expect(described_class).to have_graphql_field(:google_cloud_logging_configurations) }
  it { expect(described_class).to have_graphql_field(:merge_request_violations) }
  it { expect(described_class).to have_graphql_field(:allow_stale_runner_pruning) }
  it { expect(described_class).to have_graphql_field(:cluster_agents) }
  it { expect(described_class).to have_graphql_field(:enforce_free_user_cap) }
  it { expect(described_class).to have_graphql_field(:project_compliance_standards_adherence) }
  it { expect(described_class).to have_graphql_field(:amazon_s3_configurations) }
  it { expect(described_class).to have_graphql_field(:member_roles) }
  it { expect(described_class).to have_graphql_field(:standard_role) }
  it { expect(described_class).to have_graphql_field(:standard_roles) }
  it { expect(described_class).to have_graphql_field(:pending_members) }
  it { expect(described_class).to have_graphql_field(:value_streams) }
  it { expect(described_class).to have_graphql_field(:saved_replies) }
  it { expect(described_class).to have_graphql_field(:saved_reply) }
  it { expect(described_class).to have_graphql_field(:value_stream_analytics) }
  it { expect(described_class).to have_graphql_field(:duo_features_enabled) }
  it { expect(described_class).to have_graphql_field(:lock_duo_features_enabled) }
  it { expect(described_class).to have_graphql_field(:ai_metrics) }
  it { expect(described_class).to have_graphql_field(:ai_usage_data) }
  it { expect(described_class).to have_graphql_field(:ai_user_metrics) }
  it { expect(described_class).to have_graphql_field(:pending_member_approvals) }
  it { expect(described_class).to have_graphql_field(:dependencies) }
  it { expect(described_class).to have_graphql_field(:components) }
  it { expect(described_class).to have_graphql_field(:custom_fields) }
  it { expect(described_class).to have_graphql_field(:project_compliance_requirements_status) }

  describe 'components' do
    let_it_be(:guest) { create(:user) }
    let_it_be(:developer) { create(:user) }
    let_it_be(:group) { create(:group, developers: developer, guests: guest) }
    let_it_be(:project_1) { create(:project, namespace: group) }
    let_it_be(:sbom_occurrence_1) { create(:sbom_occurrence, project: project_1) }
    let(:component_1) { sbom_occurrence_1.component }
    let_it_be(:project_2) { create(:project, namespace: group) }
    let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, project: project_2) }
    let(:component_2) { sbom_occurrence_2.component }
    let(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
            name
            #{components_query}
              id
              name
            }
          }
        }
      )
    end

    let(:components_query) do
      if component_name
        "components(name: \"#{component_name}\") {"
      else
        "components {"
      end
    end

    subject(:query_result) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      stub_licensed_features(security_dashboard: true, dependency_scanning: true)
    end

    context 'with developer access' do
      let(:user) { developer }

      context 'when no name is passed' do
        let(:component_name) { nil }

        it 'returns all components for all projects under given group' do
          components = query_result.dig(*%w[data group components])
          names = components.pluck('name')

          expect(components.count).to be(2)
          expect(names).to match_array([component_1.name, component_2.name])
        end
      end

      context 'when name is passed' do
        let(:component_name) { component_2.name }

        it "returns all components that match the name" do
          components = query_result.dig(*%w[data group components])

          expect(components.count).to be(1)
          expect(components.first['name']).to eq(component_2.name)
        end
      end
    end

    context 'without developer access' do
      let(:user) { guest }
      let(:component_name) { component_2.name }

      it 'does not return any components' do
        components = query_result.dig(*%w[data group components])
        expect(components).to be_nil
      end
    end
  end

  describe 'dependencies' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, developers: user) }
    let_it_be(:project_1) { create(:project, namespace: group) }
    let_it_be(:sbom_occurrence_1) { create(:sbom_occurrence, project: project_1) }
    let_it_be(:project_2) { create(:project, namespace: group) }
    let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, project: project_2) }
    let_it_be(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
            name
            dependencies {
              nodes {
                id
                name
              }
            }
          }
        }
      )
    end

    subject(:query_result) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      stub_licensed_features(security_dashboard: true, dependency_scanning: true)
    end

    it "returns all dependencies for all projects under given group" do
      dependencies = query_result.dig(*%w[data group dependencies nodes])

      expect(dependencies.count).to be(2)
      expect(dependencies.first['name']).to eq(sbom_occurrence_1.component_name)
      expect(dependencies.last['name']).to eq(sbom_occurrence_2.component_name)
    end
  end

  describe 'vulnerabilities' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability) do
      create(:vulnerability, :detected, :critical, :with_read, project: project, title: 'A terrible one!')
    end

    let_it_be(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
            name
            vulnerabilities {
              nodes {
                title
                severity
                state
              }
            }
          }
        }
      )
    end

    before do
      stub_licensed_features(security_dashboard: true)

      group.add_developer(user)
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    it "returns the vulnerabilities for all projects in the group and its subgroups" do
      vulnerabilities = subject.dig('data', 'group', 'vulnerabilities', 'nodes')

      expect(vulnerabilities.count).to be(1)
      expect(vulnerabilities.first['title']).to eq('A terrible one!')
      expect(vulnerabilities.first['state']).to eq('DETECTED')
      expect(vulnerabilities.first['severity']).to eq('CRITICAL')
    end
  end

  describe 'vulnerability_identifier_search' do
    subject(:search_results) do
      GitlabSchema.execute(query, context: { current_user: current_user }).as_json
    end

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }

    let_it_be(:identifier) do
      create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-23')
    end

    let_it_be(:vulnerability_statistic) do
      create(:vulnerability_statistic, project: project)
    end

    let(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
            vulnerabilityIdentifierSearch(name: "cwe") {
            }
          }
        }
      )
    end

    before do
      stub_licensed_features(security_dashboard: true, dependency_scanning: true)
      group.add_developer(user)
    end

    context 'when the user has access' do
      let(:current_user) { user }

      it 'returns the matching search result' do
        results = search_results.dig('data', 'group', 'vulnerabilityIdentifierSearch')
        expect(results).to contain_exactly(identifier.name)
      end

      context 'when flags that solve cross-joins are disabled' do
        before do
          # This test cannot pass in a post Sec Decomposition Gitlab instance, so we skip it if
          # that's what we're running in.
          # It won't be turned off post decomposition, so this will be cleaned up with the FFs.
          # Consult https://gitlab.com/gitlab-org/gitlab/-/merge_requests/180764 for more info.
          skip_if_multiple_databases_are_setup(:sec)

          stub_feature_flags(sum_vulnerability_count_for_group_using_vulnerability_statistics: false)
          stub_feature_flags(search_identifier_name_in_group_using_vulnerability_statistics: false)
        end

        it 'returns the matching search result' do
          results = search_results.dig('data', 'group', 'vulnerabilityIdentifierSearch')
          expect(results).to contain_exactly(identifier.name)
        end
      end
    end

    context 'when user do not have access' do
      let(:current_user) { other_user }

      it 'returns nil' do
        results = search_results.dig('data', 'group', 'vulnerabilityIdentifierSearch')
        expect(results).to be_nil
      end
    end
  end

  describe '#epics_enabled?' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:group) { create(:group) }

    let(:query) do
      <<~GQL
        query {
          group(fullPath: "#{group.full_path}") {
            id,
            epicsEnabled
          }
        }
      GQL
    end

    before_all do
      group.add_owner(current_user)
    end

    subject(:epics_enabled) do
      result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json

      result.dig('data', 'group', 'epicsEnabled')
    end

    context 'when feature is available' do
      it 'returns true' do
        stub_licensed_features(epics: true)

        expect(epics_enabled).to eq(true)
      end
    end

    context 'when feature is not available' do
      it 'returns false' do
        stub_licensed_features(epics: false)

        expect(epics_enabled).to eq(false)
      end
    end
  end

  describe 'billable members count' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:group_owner) { create(:user) }
    let_it_be(:group_developer) { create(:user) }
    let_it_be(:group_guest) { create(:user) }
    let_it_be(:project_developer) { create(:user) }
    let_it_be(:project_guest) { create(:user) }

    let(:current_user) { group_owner }
    let(:query) do
      <<~GQL
        query {
          group(fullPath: "#{group.full_path}") {
            id,
            billableMembersCount
          }
        }
      GQL
    end

    before do
      group.add_owner(group_owner)
      group.add_developer(group_developer)
      group.add_guest(group_guest)
      project.add_developer(project_developer)
      project.add_guest(project_guest)
    end

    subject(:billable_members_count) do
      result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json

      result.dig('data', 'group', 'billableMembersCount')
    end

    context 'when no plan is provided' do
      it 'returns billable users count including guests' do
        expect(billable_members_count).to eq(5)
      end
    end

    context 'when a plan is provided' do
      let(:query) do
        <<~GQL
          query {
            group(fullPath: "#{group.full_path}") {
              id,
              billableMembersCount(requestedHostedPlan: "#{plan}")
            }
          }
        GQL
      end

      context 'with a plan that should include guests is provided' do
        let(:plan) { ::Plan::SILVER }

        it 'returns billable users count including guests' do
          expect(billable_members_count).to eq(5)
        end
      end

      context 'with a plan that should exclude guests is provided' do
        let(:plan) { ::Plan::ULTIMATE }

        it 'returns billable users count excluding guests when a plan that should exclude guests is provided' do
          expect(billable_members_count).to eq(3)
        end
      end
    end

    context 'without owner authorization' do
      let(:current_user) { group_developer }

      it 'does not return the billable members count' do
        expect(billable_members_count).to be_nil
      end
    end
  end

  describe 'dora field' do
    subject { described_class.fields['dora'] }

    it { is_expected.to have_graphql_type(Types::Analytics::Dora::GroupDoraType) }
  end
end
