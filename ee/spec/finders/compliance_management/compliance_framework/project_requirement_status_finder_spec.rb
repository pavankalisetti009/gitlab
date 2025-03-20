# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectRequirementStatusFinder,
  feature_category: :compliance_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: root_group) }
  let_it_be(:user) { create(:user) }

  let_it_be(:root_group_project) { create(:project, group: root_group) }
  let_it_be(:project1) { create(:project, group: sub_group) }
  let_it_be(:project2) { create(:project, group: sub_group) }
  let_it_be(:other_project) { create(:project, group: other_group) }

  let_it_be(:framework1) { create(:compliance_framework, namespace: root_group, name: 'framework1', color: '#ff00aa') }
  let_it_be(:framework2) { create(:compliance_framework, namespace: root_group, name: 'framework2', color: '#ff00ab') }
  let_it_be(:other_framework) do
    create(:compliance_framework, namespace: other_group, name: 'framework3', color: '#ff00ac')
  end

  let_it_be(:requirement1) do
    create(:compliance_requirement, namespace: root_group, framework: framework1, name: 'requirement1')
  end

  let_it_be(:requirement2) do
    create(:compliance_requirement, namespace: root_group, framework: framework1, name: 'requirement2')
  end

  let_it_be(:requirement3) do
    create(:compliance_requirement, namespace: root_group, framework: framework2, name: 'requirement3')
  end

  let_it_be(:other_requirement) do
    create(:compliance_requirement, namespace: other_group, framework: other_framework, name: 'other_requirement')
  end

  let_it_be(:requirement_status1) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: root_group_project)
  end

  let_it_be(:requirement_status2) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: root_group_project)
  end

  let_it_be(:requirement_status3) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: project1)
  end

  let_it_be(:requirement_status4) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: project1)
  end

  let_it_be(:requirement_status5) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: project2)
  end

  let_it_be(:requirement_status6) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: project2,
      created_at: 1.day.ago, updated_at: 1.day.ago)
  end

  let_it_be(:requirement_status7) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement3, project: project2)
  end

  let_it_be(:other_requirement_status) do
    create(:project_requirement_compliance_status, compliance_requirement: other_requirement, project: other_project)
  end

  let(:params) { {} }

  subject(:finder_response) { described_class.new(root_group, user, params).execute }

  describe '#execute' do
    before_all do
      root_group.add_owner(user)
    end

    context 'when the group is not licensed for the feature' do
      before do
        stub_licensed_features(group_level_compliance_adherence_report: false)
      end

      it { is_expected.to eq([]) }
    end

    context 'when the group is licensed for the feature' do
      before do
        stub_licensed_features(group_level_compliance_adherence_report: true)
      end

      context 'when user is not allowed to view the dashboard' do
        before_all do
          root_group.add_guest(user)
        end

        it { is_expected.to eq([]) }
      end

      context 'when user is allowed to view the dashboard' do
        it 'returns list of requirement statuses for all projects under the group in updated_at order' do
          expect(finder_response.to_a).to eq([requirement_status7, requirement_status5, requirement_status4,
            requirement_status3, requirement_status2, requirement_status1, requirement_status6])
        end

        it 'does not return requirement statuses which are not under root group' do
          expect(finder_response.to_a).to exclude(other_requirement_status)
        end

        context 'for subgroup' do
          subject(:finder_response) { described_class.new(sub_group, user).execute }

          it 'returns list of requirement statuses for projects under subgroup' do
            expect(finder_response.to_a).to eq([requirement_status7, requirement_status5, requirement_status4,
              requirement_status3, requirement_status6])
          end
        end

        context 'for project_ids filter' do
          let(:params) { { project_id: project1.id } }

          it 'returns requirement statuses for the specified project' do
            expect(finder_response.to_a).to eq([requirement_status4, requirement_status3])
          end
        end

        context 'for requirement_ids filter' do
          let(:params) { { requirement_id: requirement1.id } }

          it 'returns requirement statuses for the specified requirement' do
            expect(finder_response.to_a).to eq([requirement_status5, requirement_status3, requirement_status1])
          end
        end

        context 'for framework ids filter' do
          let(:params) { { framework_id: framework1.id } }

          it 'returns requirement statuses for the specified requirement' do
            expect(finder_response.to_a).to eq([requirement_status5, requirement_status4, requirement_status3,
              requirement_status2, requirement_status1, requirement_status6])
          end
        end

        context 'for all filters' do
          let(:params) { { project_id: project1.id, requirement_id: requirement1.id, framework_id: framework1.id } }

          it 'returns requirement statuses for the specified filters' do
            expect(finder_response.to_a).to eq([requirement_status3])
          end
        end
      end
    end
  end
end
