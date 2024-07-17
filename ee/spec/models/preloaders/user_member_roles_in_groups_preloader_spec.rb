# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::UserMemberRolesInGroupsPreloader, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:root_group) { create(:group, :private) }
  let_it_be(:group) { create(:group, :private, parent: root_group) }
  let_it_be(:group_member) { create(:group_member, :guest, user: user, source: group) }
  let_it_be(:root_group_member) do
    create(:group_member, :guest, user: user, source: root_group)
  end

  let(:group_list) { [group] }

  subject(:result) { described_class.new(groups: group_list, user: user).execute }

  def ability_requirements(ability)
    ability_definition = MemberRole.all_customizable_permissions[ability]
    requirements = ability_definition[:requirements]&.map(&:to_sym) || []
    requirements & MemberRole.all_customizable_group_permissions
  end

  def create_member_role(ability, member)
    create(:member_role, :guest, namespace: root_group).tap do |record|
      record.assign_attributes(ability => true)
      ability_requirements(ability).each do |requirement|
        record.assign_attributes(requirement => true)
      end
      record.save!
      record.members << member if member
    end
  end

  shared_examples 'custom roles' do |ability|
    let(:expected_abilities) { [ability, *ability_requirements(ability)].compact }

    context 'when custom_roles license is not enabled on group root ancestor' do
      it 'returns group id with nil ability value' do
        stub_licensed_features(custom_roles: false)
        create_member_role(ability, group_member)

        expect(result).to eq(group.id => nil)
      end
    end

    context 'when custom_roles license is enabled on group root ancestor' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when group has custom role' do
        let_it_be(:member_role) do
          create_member_role(ability, group_member)
        end

        context 'when custom role has ability: true' do
          let(:group_list) { Group.where(id: group.id) }

          it 'returns the group_id with a value array that includes the ability' do
            expect(result[group.id]).to match_array(expected_abilities)
          end

          context "when `#{ability}` is disabled" do
            before do
              allow(::MemberRole).to receive(:permission_enabled?)
                .and_call_original
              allow(::MemberRole).to receive(:permission_enabled?)
                .with(ability, user).and_return(false)
            end

            it { expect(result[group.id]).to match_array(ability_requirements(ability)) }
          end
        end
      end

      context 'when group has a group link assigned to a custom role' do
        let_it_be(:shared_with_group) { create(:group) }
        let_it_be(:shared_with_group_member) { create(:group_member, :guest, user: user, source: shared_with_group) }

        let_it_be(:member_role) { create_member_role(ability, nil) }

        let_it_be(:group_link) do
          create(:group_group_link, shared_group: group, shared_with_group: shared_with_group,
            group_access: Gitlab::Access::GUEST, member_role: member_role)
        end

        context 'when feature-flag `assign_custom_roles_to_group_links` is enabled' do
          before do
            stub_feature_flags(assign_custom_roles_to_group_links: true)
          end

          it 'returns the project_id with a value array that includes the ability' do
            expect(result[group.id]).to match_array(expected_abilities)
          end
        end

        context 'when feature-flag `assign_custom_roles_to_group_links` is disabled' do
          before do
            stub_feature_flags(assign_custom_roles_to_group_links: false)
          end

          it 'returns the project_id with a value array that includes the ability' do
            expect(result[group.id]).to match_array([])
          end
        end
      end

      context 'when user is a member of the group in multiple ways' do
        it 'group value array includes the ability' do
          create_member_role(ability, group_member)
          create(:member_role, :guest, namespace: root_group).tap do |record|
            record[ability] = false
            record.save!
            record.members << root_group_member
          end

          expect(result[group.id]).to match_array(expected_abilities)
        end
      end

      context 'when a user is assigned to different custom roles in group and subgroup' do
        it 'returns abilities assigned to the custom role inside both group and subgroup' do
          create_member_role(ability, group_member)
          create_member_role(:read_vulnerability, root_group_member)

          expect(result[group.id]).to match_array(expected_abilities.push(:read_vulnerability).uniq)
        end
      end

      context 'when group membership has no custom role' do
        let_it_be(:group) { create(:group, :private) }

        it 'returns group id with empty value array' do
          expect(result).to eq(group.id => [])
        end
      end

      context 'when group membership has custom role that does not enable custom permission' do
        let_it_be(:group) { create(:group, :private) }

        it 'returns group id with empty value array' do
          group_without_custom_permission_member = create(
            :group_member,
            :guest,
            user: user,
            source: group
          )
          create(:member_role, :guest, namespace: root_group).tap do |record|
            record[ability] = false
            record.save!
            record.members << group_without_custom_permission_member
          end

          expect(result).to eq(group.id => [])
        end
      end

      context 'when user has custom role that enables custom permission outside of group hierarchy' do
        it 'ignores custom role outside of group hierarchy' do
          # subgroup is within parent group of group but not above group
          subgroup = create(:group, :private, parent: root_group)
          subgroup_member = create(:group_member, :guest, user: user, source: subgroup)
          create_member_role(ability, subgroup_member)

          expect(result).to eq({ group.id => [] })
        end
      end
    end
  end

  MemberRole.all_customizable_group_permissions.each do |ability|
    it_behaves_like 'custom roles', ability
  end
end
