# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Framework, :models, feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to have_many(:projects).through(:project_settings) }

    it {
      is_expected.to have_many(:project_settings)
        .class_name('ComplianceManagement::ComplianceFramework::ProjectSettings')
    }

    it {
      is_expected.to have_many(:compliance_framework_security_policies)
          .class_name('ComplianceManagement::ComplianceFramework::SecurityPolicy')
    }

    it {
      is_expected.to have_many(:security_orchestration_policy_configurations)
        .class_name('Security::OrchestrationPolicyConfiguration').through(:compliance_framework_security_policies)
    }

    it {
      is_expected.to have_many(:compliance_requirements)
        .class_name('ComplianceManagement::ComplianceFramework::ComplianceRequirement')
    }

    it {
      is_expected.to have_many(:security_policies)
        .class_name('Security::Policy')
        .through(:compliance_framework_security_policies)
    }
  end

  describe 'validations' do
    let_it_be(:framework) { create(:compliance_framework) }

    subject { framework }

    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:name) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }
    it { is_expected.to validate_length_of(:color).is_at_most(10) }
    it { is_expected.to validate_length_of(:pipeline_configuration_full_path).is_at_most(255) }

    describe 'namespace_is_root_level_group' do
      context 'when namespace is a root group' do
        let_it_be(:namespace) { create(:group) }
        let_it_be(:framework) { build(:compliance_framework, namespace: namespace) }

        it 'is valid' do
          expect(framework).to be_valid
        end
      end

      context 'when namespace is a user namespace' do
        let_it_be(:namespace) { create(:user_namespace) }
        let_it_be(:framework) { build(:compliance_framework, namespace: namespace) }

        it 'is invalid' do
          expect(framework).not_to be_valid
          expect(framework.errors[:namespace]).to include('must be a group, user namespaces are not supported.')
        end
      end

      context 'when namespace is a subgroup' do
        let_it_be(:namespace) { create(:group, :nested) }
        let_it_be(:framework) { build(:compliance_framework, namespace: namespace) }

        it 'is invalid' do
          expect(framework).not_to be_valid
          expect(framework.errors[:namespace]).to include('must be a root group.')
        end
      end
    end
  end

  describe '#security_orchestration_policy_configurations' do
    let_it_be(:framework) { create(:compliance_framework) }

    context 'when the framework has many same policy configuration with different index' do
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

      let_it_be(:compliance_framework_security_policy1) do
        create(:compliance_framework_security_policy, framework: framework,
          policy_configuration: policy_configuration, policy_index: 0)
      end

      let_it_be(:compliance_framework_security_policy2) do
        create(:compliance_framework_security_policy, framework: framework,
          policy_configuration: policy_configuration, policy_index: 1)
      end

      it 'returns distinct policy configurations' do
        expect(framework.security_orchestration_policy_configurations).to match_array([policy_configuration])
      end
    end
  end

  describe 'color' do
    context 'with whitespace' do
      subject { create(:compliance_framework, color: ' #ABC123 ') }

      it 'strips whitespace' do
        expect(subject.color).to eq('#ABC123')
      end
    end
  end

  describe '.search' do
    let_it_be(:framework) { create(:compliance_framework, name: 'some framework name') }
    let_it_be(:framework2) { create(:compliance_framework, name: 'another framework') }

    it 'returns frameworks with a matching name' do
      expect(described_class.search(framework.name)).to eq([framework])
    end

    it 'returns frameworks with a partially matching name' do
      expect(described_class.search(framework.name[0..2])).to eq([framework])
    end

    it 'returns frameworks with a matching name regardless of the casing' do
      expect(described_class.search(framework.name.upcase)).to eq([framework])
    end

    it 'returns multiple frameworks matching with name' do
      expect(described_class.search('rame')).to match_array([framework, framework2])
    end

    it 'returns all frameworks if search string is empty' do
      expect(described_class.search('')).to match_array([framework, framework2])
    end
  end

  describe '#approval_settings_from_security_policies' do
    let_it_be(:framework) { create(:compliance_framework) }
    let_it_be(:policy_configuration1) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_configuration2) { create(:security_orchestration_policy_configuration) }
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }

    let_it_be(:policy1) do
      create(:compliance_framework_security_policy,
        framework: framework,
        policy_configuration: policy_configuration1,
        policy_index: 0)
    end

    let_it_be(:policy2) do
      create(:compliance_framework_security_policy,
        framework: framework,
        policy_configuration: policy_configuration2,
        policy_index: 0)
    end

    let_it_be(:scan_policy_read1) do
      create(:scan_result_policy_read, :prevent_approval_by_author,
        security_orchestration_policy_configuration: policy_configuration1,
        project: project1)
    end

    let_it_be(:scan_policy_read2) do
      create(:scan_result_policy_read, :prevent_approval_by_commit_author,
        security_orchestration_policy_configuration: policy_configuration1,
        project: project2)
    end

    let_it_be(:scan_policy_read3) do
      create(:scan_result_policy_read, :blocking_protected_branches,
        security_orchestration_policy_configuration: policy_configuration2,
        project: project1)
    end

    context 'when framework has multiple policy configurations with scan result policy reads' do
      it 'returns all associated project approval settings for a single project' do
        approval_settings = framework.approval_settings_from_security_policies(project1)

        expect(approval_settings).to contain_exactly(
          { "prevent_approval_by_author" => true },
          { "block_branch_modification" => true }
        )
      end

      it 'returns all associated project approval settings for multiple projects' do
        approval_settings = framework.approval_settings_from_security_policies([project1, project2])

        expect(approval_settings).to contain_exactly(
          { "prevent_approval_by_author" => true },
          { "prevent_approval_by_commit_author" => true },
          { "block_branch_modification" => true }
        )
      end

      it 'returns empty array for a project with no policy reads' do
        project3 = create(:project)

        expect(framework.approval_settings_from_security_policies(project3)).to eq([])
      end
    end
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:namespace) { create(:group) }

    describe '.with_projects' do
      before do
        create(:compliance_framework_project_setting, :first_framework, project: project)
        create(:compliance_framework_project_setting, :second_framework, project: project)
      end

      it 'returns frameworks associated with given project ids in order of addition' do
        frameworks = described_class.with_projects([project.id])

        expect(frameworks.map(&:name)).to eq(['First Framework', 'Second Framework'])
      end
    end

    describe '.ordered_by_addition_time_and_pipeline_existence' do
      before do
        create(:compliance_framework_project_setting, :first_framework, project: project)
        create(:compliance_framework_project_setting, :second_framework, project: project)
        create(:compliance_framework_project_setting, :third_framework, project: project)
        create(:compliance_framework_project_setting,
          compliance_management_framework: create(:compliance_framework,
            pipeline_configuration_full_path: 'path/to/pipeline',
            name: 'Framework with pipeline'),
          project: project, created_at: 5.days.ago
        )
      end

      it 'left joins the table correctly' do
        sql = described_class.ordered_by_addition_time_and_pipeline_existence.to_sql

        expect(sql).to include('LEFT OUTER JOIN "project_compliance_framework_settings')
      end

      it 'returns frameworks in order of their addition time' do
        ordered_frameworks = described_class.ordered_by_addition_time_and_pipeline_existence

        expect(ordered_frameworks.pluck(:name)).to eq(['Framework with pipeline', 'First Framework',
          'Second Framework', 'Third Framework'])
      end
    end

    describe '.with_requirements_and_internal_controls' do
      let_it_be(:framework) { create(:compliance_framework) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: framework) }
      let_it_be(:internal_control) do
        create(:compliance_requirements_control, compliance_requirement: requirement)
      end

      let_it_be(:external_control) do
        create(:compliance_requirements_control, :external, compliance_requirement: requirement)
      end

      it 'includes frameworks with internal controls' do
        expect(described_class.with_requirements_and_internal_controls).to include(framework)
      end

      it 'excludes external controls' do
        controls = described_class.with_requirements_and_internal_controls
                                  .first
                                  .compliance_requirements
                                  .first
                                  .compliance_requirements_controls

        expect(controls).to include(internal_control)
        expect(controls).not_to include(external_control)
      end
    end

    describe '.with_project_settings' do
      let_it_be(:framework) { create(:compliance_framework) }
      let_it_be(:project_setting) do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework,
          project: project
        )
      end

      it 'includes frameworks with project settings' do
        expect(described_class.with_project_settings).to include(framework)
      end

      it 'excludes frameworks without project settings' do
        framework_without_settings = create(:compliance_framework)

        expect(described_class.with_project_settings).not_to include(framework_without_settings)
      end
    end

    describe '.with_active_internal_controls' do
      let_it_be(:framework) { create(:compliance_framework) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: framework) }
      let_it_be(:internal_control) do
        create(:compliance_requirements_control, compliance_requirement: requirement)
      end

      let_it_be(:project_setting) do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework,
          project: project
        )
      end

      let_it_be(:mixed_framework) { create(:compliance_framework) }
      let_it_be(:mixed_requirement) { create(:compliance_requirement, framework: mixed_framework) }
      let_it_be(:mixed_internal_control) do
        create(:compliance_requirements_control, compliance_requirement: mixed_requirement)
      end

      let_it_be(:mixed_external_control) do
        create(:compliance_requirements_control, :external, compliance_requirement: mixed_requirement)
      end

      let_it_be(:mixed_project_setting) do
        create(:compliance_framework_project_setting,
          compliance_management_framework: mixed_framework,
          project: project
        )
      end

      let_it_be(:external_only_framework) { create(:compliance_framework) }
      let_it_be(:external_requirement) { create(:compliance_requirement, framework: external_only_framework) }
      let_it_be(:external_only_control) do
        create(:compliance_requirements_control, :external, compliance_requirement: external_requirement)
      end

      let_it_be(:external_project_setting) do
        create(:compliance_framework_project_setting,
          compliance_management_framework: external_only_framework,
          project: project
        )
      end

      it 'includes frameworks with internal controls and project settings' do
        result = described_class.with_active_internal_controls

        expect(result).to include(framework)
        expect(result).to include(mixed_framework)
        expect(result.count).to eq(2)
      end

      it 'excludes frameworks with only external controls' do
        expect(described_class.with_active_internal_controls).not_to include(external_only_framework)
      end

      it 'excludes frameworks without project settings' do
        framework_without_settings = create(:compliance_framework)
        requirement = create(:compliance_requirement, framework: framework_without_settings)
        create(:compliance_requirements_control, compliance_requirement: requirement)

        expect(described_class.with_active_internal_controls).not_to include(framework_without_settings)
      end

      it 'returns unique results' do
        result = described_class.with_active_internal_controls

        expect(result.count).to eq(result.distinct.count)
      end
    end
  end
end
