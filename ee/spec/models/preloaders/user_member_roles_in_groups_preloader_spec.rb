# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::UserMemberRolesInGroupsPreloader, feature_category: :permissions do
  include MemberRoleHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  let_it_be(:sub_group_1) { create(:group, :private, parent: group) }
  let_it_be(:sub_group_2) { create(:group, :private, parent: group) }

  let_it_be_with_reload(:group_member) { create(:group_member, :guest, user: user, source: group) }
  let_it_be_with_reload(:sub_group_1_member) { create(:group_member, :guest, user: user, source: sub_group_1) }
  let_it_be_with_reload(:sub_group_2_member) { create(:group_member, :guest, user: user, source: sub_group_2) }

  let(:groups_list) { [sub_group_1, sub_group_2] }

  subject(:result) { described_class.new(groups: groups_list, user: user).execute }

  before do
    stub_licensed_features(custom_roles: true)
  end

  shared_examples 'custom roles' do |ability|
    context "with ability: #{ability}" do
      let_it_be(:member_role) { create_member_role(group, ability) }

      context 'when custom_roles license is not enabled on group root ancestor' do
        before do
          stub_licensed_features(custom_roles: false)

          group_member.update!(member_role: member_role)
        end

        it 'returns group id with nil ability value' do
          expect(result).to eq(sub_group_1.id => nil, sub_group_2.id => nil)
        end
      end

      context 'when custom_roles license is enabled on group root ancestor' do
        let_it_be(:ability_2) { random_ability(ability, :all_customizable_group_permissions) }

        let_it_be(:member_role_2) { create_member_role(group, ability_2) }

        let_it_be(:expected_abilities) { expected_group_abilities(ability) }
        let_it_be(:expected_abilities_2) { expected_group_abilities(ability_2) }

        context 'when group members are assigned a custom role' do
          before do
            sub_group_1_member.update!(member_role: member_role)
            sub_group_2_member.update!(member_role: member_role_2)
          end

          context 'when ability is enabled' do
            it 'returns all requested group IDs with their respective abilities', :aggregate_failures do
              expect(result[sub_group_1.id]).to match_array(expected_abilities)
              expect(result[sub_group_2.id]).to match_array(expected_abilities_2)
            end
          end

          context 'when ability is disabled' do
            before do
              allow(::MemberRole).to receive(:permission_enabled?).and_call_original
              allow(::MemberRole).to receive(:permission_enabled?).with(ability, user).and_return(false)
            end

            it 'returns all requested group IDs without the disabled ability' do
              expect(result[sub_group_1.id]).to match_array(expected_abilities.without(ability))
            end
          end
        end

        context 'when a user is assigned to different custom roles in group and subgroup' do
          let_it_be(:expected) { (expected_abilities + expected_abilities_2).uniq }

          before do
            sub_group_1_member.update!(member_role: member_role)
            group_member.update!(member_role: member_role_2)
          end

          it 'returns abilities assigned to the custom role inside both group and subgroup' do
            expect(result[sub_group_1.id]).to match_array(expected)
          end
        end

        context 'when group membership has no custom role' do
          it 'returns group id with empty value array' do
            expect(result).to eq(sub_group_1.id => [], sub_group_2.id => [])
          end
        end

        context 'when user has custom role that enables custom permission outside of group hierarchy' do
          let_it_be(:sub_group_3) { create(:group, :private, parent: group) }
          let_it_be_with_reload(:sub_group_3_member) do
            create(:group_member, :guest, user: user, source: sub_group_3, member_role: member_role)
          end

          it 'ignores custom role outside of group hierarchy' do
            expect(result).to eq({ sub_group_1.id => [], sub_group_2.id => [] })
          end
        end
      end
    end
  end

  MemberRole.all_customizable_group_permissions.each do |ability|
    it_behaves_like 'custom roles', ability
  end

  context 'when group has a group link assigned to a custom role' do
    let_it_be(:source) { sub_group_1 }

    include_context 'with multiple users in a group with custom roles'
    it_behaves_like 'returns expected member role abilities'
  end

  context 'when multiple groups are invited with custom roles' do
    let_it_be(:source) { sub_group_1 }

    include_context 'with a user in multiple groups with custom role'
    it_behaves_like 'returns expected member role abilities for the user'
  end
end
