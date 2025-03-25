# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus, type: :model,
  feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:compliance_requirements_control) }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:compliance_requirement) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:compliance_requirements_control) }

    describe 'uniqueness validation' do
      subject { build(:project_control_compliance_status) }

      it 'validates uniqueness of project id scoped to control id' do
        create(:project_control_compliance_status)
        is_expected.to validate_uniqueness_of(:project_id)
          .scoped_to(:compliance_requirements_control_id)
          .with_message('has already been taken')
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(pass: 0, fail: 1, pending: 2) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      status = create(:project_control_compliance_status)
      expect(status).to be_valid
    end
  end

  describe '.for_project_and_control' do
    let_it_be(:project) { create(:project) }
    let_it_be(:another_project) { create(:project) }
    let_it_be(:control) { create(:compliance_requirements_control) }
    let_it_be(:another_control) { create(:compliance_requirements_control) }

    let_it_be(:status) do
      create(:project_control_compliance_status,
        project: project,
        compliance_requirements_control: control
      )
    end

    let_it_be(:another_project_status) do
      create(:project_control_compliance_status,
        project: another_project,
        compliance_requirements_control: control
      )
    end

    let_it_be(:another_control_status) do
      create(:project_control_compliance_status,
        project: project,
        compliance_requirements_control: another_control
      )
    end

    it 'returns records matching project_id and control_id' do
      result = described_class.for_project_and_control(project.id, control.id)

      expect(result).to contain_exactly(status)
    end

    it 'returns empty when no matching records exist' do
      result = described_class.for_project_and_control(non_existing_record_id, non_existing_record_id)

      expect(result).to be_empty
    end

    it 'does not return records for different project' do
      result = described_class.for_project_and_control(another_project.id, control.id)

      expect(result).not_to include(status)
      expect(result).to contain_exactly(another_project_status)
    end
  end

  describe '.create_or_find_for_project_and_control' do
    let_it_be(:project) { create(:project) }
    let_it_be(:control) { create(:compliance_requirements_control) }

    context 'when record does not exist' do
      it 'creates a new record' do
        expect do
          described_class.create_or_find_for_project_and_control(project, control)
        end.to change { described_class.count }.by(1)
      end

      it 'sets correct attributes', :aggregate_failures do
        status = described_class.create_or_find_for_project_and_control(project, control)

        expect(status.project_id).to eq(project.id)
        expect(status.compliance_requirements_control_id).to eq(control.id)
        expect(status.compliance_requirement_id).to eq(control.compliance_requirement_id)
        expect(status.namespace_id).to eq(project.namespace_id)
        expect(status).to be_pending
      end
    end

    context 'when record exists' do
      let_it_be(:existing_status) do
        create(:project_control_compliance_status,
          project: project,
          compliance_requirements_control: control)
      end

      it 'returns existing record' do
        status = described_class.create_or_find_for_project_and_control(project, control)

        expect(status).to eq(existing_status)
      end

      it 'does not create a new record' do
        expect do
          described_class.create_or_find_for_project_and_control(project, control)
        end.not_to change { described_class.count }
      end
    end

    context 'when concurrent creation occurs' do
      context "when ActiveRecord::RecordNotUnique is raised" do
        let!(:existing_status) do
          create(:project_control_compliance_status,
            project: project,
            compliance_requirements_control: control)
        end

        before do
          empty_relation = described_class.none
          record_relation = described_class.where(id: existing_status.id)

          allow(described_class).to receive(:for_project_and_control)
                                      .with(project.id, control.id)
                                      .and_return(empty_relation, record_relation)

          allow(described_class).to receive(:create!)
                                      .and_raise(ActiveRecord::RecordNotUnique)
        end

        it 'handles race condition and returns existing record' do
          status = described_class.create_or_find_for_project_and_control(project, control)

          expect(status).to eq(existing_status)
        end
      end

      context "when ActiveRecord::RecordInvalid is raised" do
        let!(:existing_status) do
          create(:project_control_compliance_status,
            project: project,
            compliance_requirements_control: control)
        end

        before do
          empty_relation = described_class.none
          record_relation = described_class.where(id: existing_status.id)

          allow(described_class).to receive(:for_project_and_control)
                                      .with(project.id, control.id)
                                      .and_return(empty_relation, record_relation)

          allow(described_class).to receive(:create!)
                                      .and_raise(
                                        ActiveRecord::RecordInvalid.new(
                                          existing_status.tap do |status|
                                            status.errors.add(:project_id, :taken, message: "has already been taken")
                                          end
                                        )
                                      )
        end

        it 'handles race condition and returns existing record' do
          status = described_class.create_or_find_for_project_and_control(project, control)

          expect(status).to eq(existing_status)
        end
      end
    end

    context "when ActiveRecord::RecordInvalid isn't cause by project_id" do
      let!(:existing_status) do
        create(:project_control_compliance_status,
          project: project,
          compliance_requirements_control: control)
      end

      before do
        empty_relation = described_class.none
        record_relation = described_class.where(id: existing_status.id)

        allow(described_class).to receive(:for_project_and_control)
                                    .with(project.id, control.id)
                                    .and_return(empty_relation, record_relation)

        allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'raises the error' do
        expect do
          described_class.create_or_find_for_project_and_control(project, control)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe '.for_projects' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project1) { create(:project, namespace: namespace) }
      let_it_be(:project2) { create(:project, namespace: namespace) }

      let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework, namespace: namespace) }
      let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }

      let_it_be(:status1) do
        create(:project_control_compliance_status, project: project1, compliance_requirements_control: control,
          compliance_requirement: requirement)
      end

      let_it_be(:status2) do
        create(:project_control_compliance_status, project: project2, compliance_requirements_control: control,
          compliance_requirement: requirement)
      end

      context 'when given a single project ID' do
        it 'returns statuses for the specified project' do
          expect(described_class.for_projects(project1.id)).to contain_exactly(status1)
        end
      end

      context 'when given multiple project IDs' do
        it 'returns statuses for all specified projects' do
          expect(described_class.for_projects([project1.id, project2.id])).to contain_exactly(status1, status2)
        end
      end

      context 'when given an array with a single project ID' do
        it 'returns statuses for the specified project' do
          expect(described_class.for_projects([project1.id])).to contain_exactly(status1)
        end
      end

      context 'when given an empty array' do
        it 'returns an empty relation' do
          expect(described_class.for_projects([])).to be_empty
        end
      end

      context 'when given nil' do
        it 'returns an empty relation' do
          expect(described_class.for_projects(nil)).to be_empty
        end
      end

      context 'when given non-existent project IDs' do
        it 'returns an empty relation' do
          expect(described_class.for_projects(non_existing_record_id)).to be_empty
        end
      end

      context 'when given a mix of existing and non-existent project IDs' do
        it 'returns statuses only for existing projects' do
          expect(described_class.for_projects([project1.id, non_existing_record_id])).to contain_exactly(status1)
        end
      end

      context 'when chained with other scopes' do
        before do
          status1.update!(status: :pass)
          status2.update!(status: :fail)
        end

        it 'works correctly with other scopes' do
          result = described_class.for_projects([project1.id, project2.id]).where(status: :pass)
          expect(result).to contain_exactly(status1)
        end
      end
    end

    describe '.for_requirements' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
      let_it_be(:requirement1) do
        create(:compliance_requirement, framework: compliance_framework, namespace: namespace)
      end

      let_it_be(:requirement2) do
        create(:compliance_requirement, framework: compliance_framework, namespace: namespace)
      end

      let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement1) }
      let_it_be(:control2) { create(:compliance_requirements_control, compliance_requirement: requirement2) }

      let_it_be(:status1) do
        create(:project_control_compliance_status, project: project, compliance_requirements_control: control1,
          compliance_requirement: requirement1)
      end

      let_it_be(:status2) do
        create(:project_control_compliance_status, project: project, compliance_requirements_control: control2,
          compliance_requirement: requirement2)
      end

      context 'when given a single requirement ID' do
        it 'returns statuses for the specified requirement' do
          expect(described_class.for_requirements(requirement1.id)).to contain_exactly(status1)
        end
      end

      context 'when given multiple requirement IDs' do
        it 'returns statuses for all specified requirements' do
          expect(described_class.for_requirements([requirement1.id,
            requirement2.id])).to contain_exactly(status1, status2)
        end
      end

      context 'when given an array with a single requirement ID' do
        it 'returns statuses for the specified requirement' do
          expect(described_class.for_requirements([requirement1.id])).to contain_exactly(status1)
        end
      end

      context 'when given an empty array' do
        it 'returns an empty relation' do
          expect(described_class.for_requirements([])).to be_empty
        end
      end

      context 'when given nil' do
        it 'returns an empty relation' do
          expect(described_class.for_requirements(nil)).to be_empty
        end
      end

      context 'when given non-existent requirement IDs' do
        it 'returns an empty relation' do
          expect(described_class.for_requirements(non_existing_record_id)).to be_empty
        end
      end

      context 'when given a mix of existing and non-existent requirement IDs' do
        it 'returns statuses only for existing requirements' do
          expect(described_class.for_requirements([requirement1.id,
            non_existing_record_id])).to contain_exactly(status1)
        end
      end

      context 'when chained with other scopes' do
        before do
          status1.update!(status: :pass)
          status2.update!(status: :fail)
        end

        it 'works correctly with other scopes' do
          result = described_class.for_requirements([requirement1.id, requirement2.id]).where(status: :pass)
          expect(result).to contain_exactly(status1)
        end
      end
    end
  end
end
