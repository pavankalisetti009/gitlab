# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::TriggeredWorkflow, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:vulnerability_occurrence).class_name('Vulnerabilities::Finding') }
    it { is_expected.to belong_to(:workflow).class_name('Ai::DuoWorkflows::Workflow') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:vulnerability_occurrence) }
    it { is_expected.to validate_presence_of(:workflow) }
    it { is_expected.to validate_presence_of(:workflow_name) }
  end

  describe 'enums' do
    it 'validates enum values' do
      is_expected.to define_enum_for(:workflow_name).with_values(sast_fp_detection: 0, resolve_sast_vulnerability: 1)
    end
  end

  describe 'callbacks' do
    describe '#assign_project_id' do
      let_it_be(:project) { create(:project) }
      let_it_be(:vulnerability_occurrence) { create(:vulnerabilities_finding, project: project) }
      let_it_be(:workflow) { create(:duo_workflows_workflow) }

      context 'when project_id is not set' do
        it 'assigns project_id from vulnerability_occurrence' do
          triggered_workflow = build(:vulnerability_triggered_workflow,
            vulnerability_occurrence: vulnerability_occurrence,
            workflow: workflow,
            project_id: nil
          )

          expect { triggered_workflow.valid? }.to change { triggered_workflow.project_id }.to(project.id)
        end
      end

      context 'when project_id is already set' do
        let_it_be(:other_project) { create(:project) }

        it 'does not override existing project_id' do
          triggered_workflow = build(:vulnerability_triggered_workflow,
            vulnerability_occurrence: vulnerability_occurrence,
            workflow: workflow,
            project_id: other_project.id
          )

          expect { triggered_workflow.valid? }.not_to change { triggered_workflow.project_id }
          expect(triggered_workflow.project_id).to eq(other_project.id)
        end
      end

      context 'when vulnerability_occurrence is nil' do
        it 'does not assign project_id' do
          triggered_workflow = build(:vulnerability_triggered_workflow,
            vulnerability_occurrence: nil,
            workflow: workflow,
            project_id: nil
          )

          expect { triggered_workflow.valid? }.not_to change { triggered_workflow.project_id }
          expect(triggered_workflow.project_id).to be_nil
        end
      end
    end
  end

  describe 'factory' do
    it 'creates a valid triggered workflow' do
      triggered_workflow = build(:vulnerability_triggered_workflow)

      expect(triggered_workflow).to be_valid
    end
  end
end
