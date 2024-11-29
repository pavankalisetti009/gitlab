# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::UserMemberRolesInProjectsPreloader, feature_category: :permissions do
  include MemberRoleHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }

  let_it_be(:project) { create(:project, :private, group: sub_group) }
  let_it_be(:project_2) { create(:project, :private, group: group) }

  let_it_be(:group_member) { create(:group_member, :guest, user: user, source: group) }
  let_it_be(:sub_group_member) { create(:group_member, :guest, user: user, source: sub_group) }

  let_it_be_with_reload(:project_member) { create(:project_member, :guest, user: user, source: project) }
  let_it_be_with_reload(:project_2_member) { create(:project_member, :guest, user: user, source: project_2) }

  let(:projects_list) { [project, project_2] }

  subject(:result) { described_class.new(projects: projects_list, user: user).execute }

  before do
    stub_licensed_features(custom_roles: true)
  end

  shared_examples 'custom roles' do |ability|
    context "with ability: #{ability}" do
      let_it_be(:member_role) { create_member_role(group, ability) }

      context 'when custom_roles license is not enabled on project root ancestor' do
        before do
          stub_licensed_features(custom_roles: false)

          project_member.update!(member_role: member_role)
        end

        it 'returns project id with nil ability value' do
          expect(result).to eq(project.id => nil, project_2.id => nil)
        end
      end

      context 'when custom_roles license is enabled on project root ancestor' do
        let_it_be(:ability_2) { random_ability(ability, :all_customizable_project_permissions) }

        let_it_be(:member_role_2) { create_member_role(group, ability_2) }

        let_it_be(:expected_abilities) { expected_project_abilities(ability) }
        let_it_be(:expected_abilities_2) { expected_project_abilities(ability_2) }

        context 'when project members are assigned a custom role' do
          before do
            project_member.update!(member_role: member_role)
            project_2_member.update!(member_role: member_role_2)
          end

          context 'when ability is enabled' do
            it 'returns all requested project IDs with their respective abilities' do
              expect(result[project.id]).to match_array(expected_abilities)
              expect(result[project_2.id]).to match_array(expected_abilities_2)
            end

            it 'avoids N+1 queries' do
              projects = [project]
              control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
                described_class.new(projects: projects, user: user).execute
              end

              projects << create(:project, :private, group: create(:group, parent: group))

              expect do
                described_class.new(projects: projects, user: user).execute
              end.to issue_same_number_of_queries_as(control).or_fewer
            end
          end

          context 'when ability is disabled' do
            before do
              allow(::MemberRole).to receive(:permission_enabled?).and_call_original
              allow(::MemberRole).to receive(:permission_enabled?).with(ability, user).and_return(false)
            end

            it 'returns all requested project IDs without the disabled ability' do
              expect(result[project.id]).to match_array(expected_abilities.without(ability))
            end
          end

          context 'when ActiveRecord::Relation of projects passed' do
            let(:projects_list) { Project.where(id: project.id) }

            it 'returns the project_id with a value array that includes the ability' do
              expect(result[project.id]).to match_array(expected_abilities)
            end
          end
        end

        context 'when a user is assigned custom roles in both group and project' do
          let(:expected) { (expected_abilities + expected_abilities_2).uniq }

          before do
            project_member.update!(member_role: member_role)
            group_member.update!(member_role: member_role_2)
          end

          it 'returns abilities assigned to the custom role inside both project and group' do
            expect(result[project.id]).to match_array(expected)
          end
        end

        context 'when a user is assigned custom roles in group, sub_group and project' do
          let_it_be(:expected) { (expected_abilities + [:read_code, :read_vulnerability]).uniq }

          let_it_be(:read_code_member_role) { create_member_role(group, :read_code) }
          let_it_be(:read_vulnerability_member_role) { create_member_role(group, :read_vulnerability) }

          before do
            project_member.update!(member_role: member_role)
            group_member.update!(member_role: read_code_member_role)
            sub_group_member.update!(member_role: read_vulnerability_member_role)
          end

          it 'returns abilities assigned to the custom role inside group, sub_group and project' do
            expect(result[project.id]).to match_array(expected)
          end
        end

        context 'when project membership has no custom role' do
          it 'returns project id with empty value array' do
            expect(result).to eq(project.id => [], project_2.id => [])
          end
        end

        context 'when user has custom role that enables custom permission outside of project hierarchy' do
          let_it_be(:sub_group_2) { create(:group, :private, parent: group) }
          let_it_be_with_reload(:sub_group_2_member) do
            create(:group_member, :guest, user: user, source: sub_group_2, member_role: member_role)
          end

          it 'ignores custom role outside of project hierarchy' do
            expect(result).to eq({ project.id => [], project_2.id => [] })
          end
        end
      end

      it 'avoids N+1 queries' do
        projects = [project]
        described_class.new(projects: projects, user: user).execute

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          described_class.new(projects: projects, user: user).execute
        end

        projects = [project, create(:project, :private, :in_group)]

        expect do
          described_class.new(projects: projects, user: user).execute
        end.to issue_same_number_of_queries_as(control)
      end
    end
  end

  MemberRole.all_customizable_project_permissions.each do |ability|
    it_behaves_like 'custom roles', ability
  end

  context 'when project namespace has a group link assigned to a custom role' do
    let(:source) { project }

    include_context 'with member roles assigned to group links'
    it_behaves_like 'returns expected member role abilities'
  end
end
