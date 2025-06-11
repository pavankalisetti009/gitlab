# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::ComplianceManagement::Projects::ComplianceViolationPolicy, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:requirement) { create(:compliance_requirement, namespace: group, framework: framework) }
  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }
  let_it_be(:audit_event) { create(:audit_event, :project_event, target_project: project, user: user) }

  let_it_be(:violation) do
    create(:project_compliance_violation, namespace: group, project: project,
      audit_event: audit_event,
      compliance_control: control,
      status: 0
    )
  end

  subject(:policy) { described_class.new(user, violation) }

  context 'when user does have access to group' do
    before_all do
      group.add_owner(user)
    end

    context 'when group is licensed' do
      before do
        stub_licensed_features(
          group_level_compliance_violations_report: true
        )
      end

      it { is_expected.to be_allowed(:read_compliance_violations_report) }
    end

    context 'when group is not licensed' do
      before do
        stub_licensed_features(
          group_level_compliance_violations_report: false
        )
      end

      it { is_expected.not_to be_allowed(:read_compliance_violations_report) }
    end
  end

  context 'when user does have access to project' do
    before_all do
      project.add_owner(user)
    end

    context 'when project is licensed' do
      before do
        stub_licensed_features(
          project_level_compliance_violations_report: true
        )
      end

      it { is_expected.to be_allowed(:read_compliance_violations_report) }
    end

    context 'when project is not licensed' do
      before do
        stub_licensed_features(
          project_level_compliance_violations_report: false
        )
      end

      it { is_expected.not_to be_allowed(:read_compliance_violations_report) }
    end
  end
end
