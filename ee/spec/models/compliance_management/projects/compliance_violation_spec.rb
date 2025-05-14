# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ComplianceViolation, type: :model,
  feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:namespace) }

    it 'belongs to compliance_control' do
      is_expected.to belong_to(:compliance_control)
        .class_name('ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl')
        .with_foreign_key('compliance_requirements_control_id')
    end

    it { is_expected.to belong_to(:audit_event).class_name('AuditEvent') }

    it 'has many compliance_violation_issues' do
      is_expected.to have_many(:compliance_violation_issues)
        .class_name('ComplianceManagement::Projects::ComplianceViolationIssue')
        .with_foreign_key('project_compliance_violation_id')
    end

    it { is_expected.to have_many(:issues).through(:compliance_violation_issues) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_control) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:audit_event) }

    describe 'uniqueness validations' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:audit_event) { create(:audit_event, :project_event, target_project: project) }
      let_it_be(:other_audit_event) { create(:audit_event, :project_event, target_project: project) }
      let_it_be(:other_compliance_control) { create(:compliance_requirements_control, namespace: namespace) }

      context 'when creating a duplicate violation' do
        before do
          create(:project_compliance_violation,
            project: project,
            namespace: namespace,
            compliance_control: compliance_control,
            audit_event: audit_event
          )
        end

        subject(:duplicate_violation) do
          build(:project_compliance_violation,
            project: project,
            namespace: namespace,
            compliance_control: compliance_control,
            audit_event: audit_event
          )
        end

        it 'is invalid' do
          expect(duplicate_violation).not_to be_valid
          expect(duplicate_violation.errors[:audit_event_id])
            .to include('has already been recorded as a violation for this compliance control')
        end
      end
    end

    describe 'custom validations' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:other_project) { create(:project, namespace: other_namespace) }
      let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:other_compliance_control) { create(:compliance_requirements_control, namespace: other_namespace) }

      describe '#project_belongs_to_namespace' do
        context 'when project belongs to namespace' do
          subject(:violation) do
            build(:project_compliance_violation,
              project: project,
              namespace: namespace,
              compliance_control: compliance_control,
              audit_event: create(:audit_event, :project_event, target_project: project)
            )
          end

          it 'is valid' do
            expect(violation).to be_valid
          end
        end

        context 'when project does not belong to namespace' do
          subject(:violation) do
            build(:project_compliance_violation,
              project: project,
              namespace: other_namespace,
              compliance_control: compliance_control,
              audit_event: create(:audit_event, :project_event, target_project: project)
            )
          end

          it 'is invalid' do
            expect(violation).not_to be_valid
            expect(violation.errors[:project]).to include('must belong to the specified namespace')
          end
        end
      end

      describe '#compliance_control_belongs_to_namespace' do
        context 'when compliance control belongs to namespace' do
          subject(:violation) do
            build(:project_compliance_violation,
              project: project,
              namespace: namespace,
              compliance_control: compliance_control,
              audit_event: create(:audit_event, :project_event, target_project: project)
            )
          end

          it 'is valid' do
            expect(violation).to be_valid
          end
        end

        context 'when compliance control does not belong to namespace' do
          subject(:violation) do
            build(:project_compliance_violation,
              project: project,
              namespace: namespace,
              compliance_control: other_compliance_control,
              audit_event: create(:audit_event, :project_event, target_project: project)
            )
          end

          it 'is invalid' do
            expect(violation).not_to be_valid
            expect(violation.errors[:compliance_control]).to include('must belong to the specified namespace')
          end
        end
      end

      describe '#audit_event_has_valid_entity_association' do
        context 'with Project entity type' do
          context 'when audit event references the project' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event: create(:audit_event, :project_event, target_project: project)
              )
            end

            it 'is valid' do
              expect(violation).to be_valid
            end
          end

          context 'when audit event references a different project' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event: create(:audit_event, :project_event, target_project: other_project)
              )
            end

            it 'is invalid' do
              expect(violation).not_to be_valid
              expect(violation.errors[:audit_event]).to include('must reference the specified project as its entity')
            end
          end
        end

        context 'with Group entity type' do
          context 'when audit event references the namespace' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event: create(:audit_event, :group_event, target_group: namespace)
              )
            end

            it 'is valid' do
              expect(violation).to be_valid
            end
          end

          context 'when audit event references a namespace in the hierarchy' do
            let_it_be(:sub_group) { create(:group, parent: namespace) }
            let_it_be(:sub_group_project) { create(:project, namespace: sub_group) }

            subject(:violation) do
              build(:project_compliance_violation,
                project: sub_group_project,
                namespace: sub_group,
                compliance_control: compliance_control,
                audit_event: create(:audit_event, :group_event, target_group: namespace)
              )
            end

            it 'is valid' do
              expect(violation).to be_valid
            end
          end

          context 'when audit event references a namespace not in the hierarchy' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event: create(:audit_event, :group_event, target_group: other_namespace)
              )
            end

            it 'is invalid' do
              expect(violation).not_to be_valid
              expect(violation.errors[:audit_event]).to include('must reference the specified namespace as its entity')
            end
          end
        end

        context 'when entity type is not Project or Group' do
          subject(:violation) do
            build(:project_compliance_violation,
              project: project,
              namespace: namespace,
              compliance_control: compliance_control,
              audit_event: create(:user_audit_event)
            )
          end

          it 'is invalid' do
            expect(violation).not_to be_valid
            expect(violation.errors[:audit_event])
              .to include('must be associated with either a Project or Group entity type')
          end
        end
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(detected: 0, in_review: 1, resolved: 2, dismissed: 3) }
  end
end
