# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectSettings do
  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: sub_group) }

  subject { build(:compliance_framework_project_setting, project: project) }

  describe 'Associations' do
    it 'belongs to project' do
      expect(subject).to belong_to(:project)
    end
  end

  describe 'Validations' do
    it 'confirms the presence of project' do
      expect(subject).to validate_presence_of(:project)
    end
  end

  describe 'creation of ComplianceManagement::Framework record' do
    subject { create(:compliance_framework_project_setting, :sox, project: project) }

    it 'creates a new record' do
      expect(subject.reload.compliance_management_framework.name).to eq('SOX')
    end
  end

  describe 'set a custom ComplianceManagement::Framework' do
    let(:framework) { create(:compliance_framework, name: 'my framework') }

    it 'assigns the framework' do
      subject.compliance_management_framework = framework
      subject.save!

      expect(subject.compliance_management_framework.name).to eq('my framework')
    end
  end

  describe '.by_framework_and_project' do
    let_it_be(:framework1) do
      create(:compliance_framework, namespace: project.group.root_ancestor, name: 'framework1')
    end

    let_it_be(:setting) do
      create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework1)
    end

    it 'returns the setting' do
      expect(described_class.by_framework_and_project(project.id, framework1.id))
        .to eq([setting])
    end
  end

  describe '.find_or_create_by_project' do
    let_it_be(:framework) { create(:compliance_framework, namespace: project.group.root_ancestor) }

    subject(:assign_framework) { described_class.find_or_create_by_project(project, framework) }

    context 'when there is no compliance framework assigned to a project' do
      it 'creates a new record' do
        expect { assign_framework }.to change { described_class.count }.by(1)
      end

      it 'creates the compliance framework project settings' do
        assign_framework

        setting = described_class.last

        expect(setting.project).to eq(project)
        expect(setting.compliance_management_framework).to eq(framework)
      end
    end

    context 'when there is a compliance framework assigned to a project' do
      let_it_be(:project_setting) { create(:compliance_framework_project_setting, project: project) }

      it 'does not create a new record' do
        expect { assign_framework }.not_to change { described_class.count }
      end

      it 'updates the compliance framework project settings' do
        assign_framework

        setting = described_class.last

        expect(setting.project).to eq(project)
        expect(setting.compliance_management_framework).to eq(framework)
      end
    end
  end
end
