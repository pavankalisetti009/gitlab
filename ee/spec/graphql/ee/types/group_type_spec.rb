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
  it { expect(described_class).to have_graphql_field(:standard_roles) }
  it { expect(described_class).to have_graphql_field(:pending_members) }
  it { expect(described_class).to have_graphql_field(:value_streams) }
  it { expect(described_class).to have_graphql_field(:saved_replies) }
  it { expect(described_class).to have_graphql_field(:saved_reply) }
  it { expect(described_class).to have_graphql_field(:value_stream_analytics) }
  it { expect(described_class).to have_graphql_field(:duo_features_enabled) }
  it { expect(described_class).to have_graphql_field(:lock_duo_features_enabled) }
  it { expect(described_class).to have_graphql_field(:marked_for_deletion_on) }
  it { expect(described_class).to have_graphql_field(:ai_metrics) }
  it { expect(described_class).to have_graphql_field(:is_adjourned_deletion_enabled) }
  it { expect(described_class).to have_graphql_field(:permanent_deletion_date) }
  it { expect(described_class).to have_graphql_field(:pending_member_approvals) }
  it { expect(described_class).to have_graphql_field(:dependencies) }

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

    it { is_expected.to have_graphql_type(Types::DoraType) }
  end

  describe 'group adjourned deletion fields', feature_category: :groups_and_projects do
    let_it_be(:user) { create(:user) }
    let_it_be(:pending_delete_group) { create(:group_with_deletion_schedule, marked_for_deletion_on: Time.current) }

    let_it_be(:query) do
      %(
        query {
          group(fullPath: "#{pending_delete_group.full_path}") {
            markedForDeletionOn
            isAdjournedDeletionEnabled
            permanentDeletionDate
          }
        }
      )
    end

    before do
      pending_delete_group.add_developer(user)
    end

    subject(:group_data) do
      result = GitlabSchema.execute(query, context: { current_user: user }).as_json
      {
        marked_for_deletion_on: result.dig('data', 'group', 'markedForDeletionOn'),
        is_adjourned_deletion_enabled: result.dig('data', 'group', 'isAdjournedDeletionEnabled'),
        permanent_deletion_date: result.dig('data', 'group', 'permanentDeletionDate')
      }
    end

    context 'with adjourned deletion disabled' do
      before do
        allow_next_found_instance_of(Group) do |group|
          allow(group).to receive(:adjourned_deletion?).and_return(false)
        end
      end

      it 'marked_for_deletion_on returns nil' do
        expect(group_data[:marked_for_deletion_on]).to be_nil
      end

      it 'is_adjourned_deletion_enabled returns false' do
        expect(group_data[:is_adjourned_deletion_enabled]).to be false
      end

      it 'permanent_deletion_date returns nil' do
        expect(group_data[:permanent_deletion_date]).to be_nil
      end
    end

    context 'with adjourned deletion enabled' do
      before do
        allow_next_found_instance_of(Group) do |group|
          allow(group).to receive(:adjourned_deletion?).and_return(true)
        end
      end

      it 'marked_for_deletion_on returns correct date' do
        marked_for_deletion_on_time = Time.zone.parse(group_data[:marked_for_deletion_on])

        expect(marked_for_deletion_on_time).to eq(pending_delete_group.marked_for_deletion_on.iso8601)
      end

      it 'is_adjourned_deletion_enabled returns true' do
        expect(group_data[:is_adjourned_deletion_enabled]).to be true
      end

      it 'permanent_deletion_date returns correct date' do
        expect(group_data[:permanent_deletion_date]).to \
          eq(pending_delete_group.permanent_deletion_date(Time.now.utc).strftime('%F'))
      end
    end
  end
end
