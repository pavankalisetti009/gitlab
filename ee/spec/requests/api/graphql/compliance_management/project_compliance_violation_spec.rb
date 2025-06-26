# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting a project compliance violation', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let(:violation_params) { { id: global_id_of(violation1) } }
  let(:query) { graphql_query_for('projectComplianceViolation', violation_params, fields) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }

  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:requirement) { create(:compliance_requirement, namespace: group, framework: framework) }
  let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement) }
  let_it_be(:control2) do
    create(:compliance_requirements_control, :project_visibility_not_internal, compliance_requirement: requirement)
  end

  let_it_be(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id) }

  let_it_be(:violation1) do
    create(:project_compliance_violation, namespace: group, project: project,
      audit_event_id: audit_event.id,
      audit_event_table_name: :project_audit_events,
      compliance_control: control1,
      status: 0
    )
  end

  let_it_be(:violation2) do
    create(:project_compliance_violation, namespace: group, project: project,
      audit_event_id: audit_event.id,
      audit_event_table_name: :project_audit_events,
      compliance_control: control2,
      status: 1
    )
  end

  let(:fields) do
    <<~GRAPHQL
      id
      createdAt
      status
      complianceControl {
        id
        name
      }
      project {
        id
        name
      }
    GRAPHQL
  end

  let(:violation1_output) do
    get_violation_output(violation1)
  end

  def get_violation_output(violation)
    {
      'id' => violation.to_global_id.to_s,
      'createdAt' => violation.created_at.iso8601,
      'status' => violation.status.to_s.upcase,
      'project' => {
        'id' => violation.project.to_global_id.to_s,
        'name' => violation.project.name
      },
      'complianceControl' => {
        'id' => violation.compliance_control.to_global_id.to_s,
        'name' => violation.compliance_control.name
      }
    }
  end

  context 'when the feature is licensed' do
    before do
      stub_licensed_features(group_level_compliance_violations_report: true)
    end

    context 'when the user is authorized' do
      before_all do
        group.add_owner(user)
      end

      it 'returns the project compliance violation' do
        post_graphql(query, current_user: user)

        expect(graphql_data_at(:project_compliance_violation)).to eq(violation1_output)
      end
    end

    context 'when the user is unauthorized' do
      before_all do
        group.add_maintainer(user)
      end

      it 'returns null' do
        post_graphql(query, current_user: user)

        expect(graphql_data_at(:project_compliance_violation)).to be_nil
      end
    end
  end

  context 'when the feature is not licensed' do
    before_all do
      group.add_owner(user)
    end

    before do
      stub_licensed_features(group_level_compliance_violations_report: false)
    end

    it 'returns null' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(:project_compliance_violation)).to be_nil
    end
  end
end
