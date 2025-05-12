# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting the compliance requirement statuses for a project', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }

  let_it_be(:framework1) { create(:compliance_framework, namespace: group, name: 'framework1', color: '#ff00aa') }
  let_it_be(:framework2) { create(:compliance_framework, namespace: group, name: 'framework2', color: '#ff00ab') }

  let_it_be(:requirement1) do
    create(:compliance_requirement, namespace: group, framework: framework1, name: 'requirement1')
  end

  let_it_be(:requirement2) do
    create(:compliance_requirement, namespace: group, framework: framework1, name: 'requirement2')
  end

  let_it_be(:requirement3) do
    create(:compliance_requirement, namespace: group, framework: framework2, name: 'requirement3')
  end

  let_it_be(:requirement_status1) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: project1)
  end

  let_it_be(:requirement_status2) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: project1)
  end

  let_it_be(:requirement_status3) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement3, project: project1)
  end

  let_it_be(:requirement_status4) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: project2)
  end

  let_it_be(:requirement_status5) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: project2)
  end

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id
        updatedAt
        passCount
        failCount
        pendingCount
        project {
          id
          name
        }
        complianceRequirement {
          id
          name
        }
        complianceFramework {
          id
          name
          color
          editPath
        }
      }
    GRAPHQL
  end

  let(:requirement_status1_output) do
    get_requirement_status_output(requirement_status1)
  end

  let(:requirement_status2_output) do
    get_requirement_status_output(requirement_status2)
  end

  let(:requirement_status3_output) do
    get_requirement_status_output(requirement_status3)
  end

  let(:requirement_status4_output) do
    get_requirement_status_output(requirement_status4)
  end

  let(:requirement_status5_output) do
    get_requirement_status_output(requirement_status5)
  end

  let(:requirement_statuses) { graphql_data_at(:project, :compliance_requirement_statuses, :nodes) }

  def get_requirement_status_output(requirement_status)
    {
      'id' => requirement_status.to_global_id.to_s,
      'updatedAt' => requirement_status.updated_at.iso8601,
      'passCount' => requirement_status.pass_count,
      'failCount' => requirement_status.fail_count,
      'pendingCount' => requirement_status.pending_count,
      'project' => {
        'id' => requirement_status.project.to_global_id.to_s,
        'name' => requirement_status.project.name
      },
      'complianceRequirement' => {
        'id' => requirement_status.compliance_requirement.to_global_id.to_s,
        'name' => requirement_status.compliance_requirement.name
      },
      'complianceFramework' => {
        'id' => requirement_status.compliance_framework.to_global_id.to_s,
        'name' => requirement_status.compliance_framework.name,
        'color' => requirement_status.compliance_framework.color,
        'editPath' => edit_path(requirement_status, group)
      }
    }
  end

  def edit_path(requirement_status, group)
    "/groups/#{group.name}/-/security/compliance_dashboard/frameworks/#{requirement_status.compliance_framework.id}"
  end

  def query(params = {})
    graphql_query_for(
      :project, { full_path: project1.full_path },
      query_graphql_field("complianceRequirementStatuses", params, fields)
    )
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true, group_level_compliance_adherence_report: true,
      project_level_compliance_dashboard: true, project_level_compliance_adherence_report: true
    )
  end

  shared_examples 'returns nil' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(requirement_statuses).to be_nil
    end
  end

  context 'when the user is unauthorized' do
    context 'when not part of the project' do
      it_behaves_like 'returns nil'
    end

    context 'with maintainer access' do
      before_all do
        project1.add_maintainer(current_user)
      end

      it_behaves_like 'returns nil'
    end
  end

  context 'when the user is authorized' do
    before_all do
      project1.add_owner(current_user)
      group.add_owner(current_user)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    it 'finds all the compliance requirement statuses only for the project', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      statuses = requirement_statuses

      expect(statuses).to eq(
        [requirement_status3_output, requirement_status2_output, requirement_status1_output]
      )

      expect(statuses).not_to include(
        [requirement_status4_output, requirement_status5_output]
      )
    end
  end
end
