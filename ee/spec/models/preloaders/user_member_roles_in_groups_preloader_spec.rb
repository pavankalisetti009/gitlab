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

    stub_feature_flags(track_user_group_member_roles_accuracy: false)
  end

  shared_examples 'custom roles' do |ability|
    context "with ability: #{ability}" do
      let_it_be(:member_role) { create_member_role(group, ability) }

      context 'when custom_roles license is not enabled on group root ancestor' do
        before do
          stub_licensed_features(custom_roles: false)

          group_member.update!(member_role: member_role)
        end

        it 'returns group id with empty array' do
          expect(result).to eq(sub_group_1.id => [], sub_group_2.id => [])
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

            it 'logs the query' do
              expect(Gitlab::AppLogger).to receive(:info).with({
                class: described_class.name,
                user_id: user.id,
                groups_count: 2,
                group_ids: groups_list.map(&:id).first(10)
              })

              result
            end

            it 'avoids N+1 queries' do
              control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
                described_class.new(groups: [sub_group_1], user: user).execute
              end

              expect do
                described_class.new(groups: [sub_group_1, sub_group_2], user: user).execute
              end.to issue_same_number_of_queries_as(control).or_fewer
            end

            context 'with RequestStore enabled', :request_store do
              it 'only requests the extra groups when uncached groups are passed' do
                described_class.new(groups: [sub_group_1], user: user).execute

                queries = ActiveRecord::QueryRecorder.new do
                  described_class.new(groups: [sub_group_1, sub_group_2], user: user).execute
                end

                expect(queries.count).to eq(3)
                expect(queries.log_message).to match(/VALUES \(#{sub_group_2.id}/)
                expect(queries.log_message).not_to match(/VALUES \(#{sub_group_1.id}/)
              end
            end

            context 'when an array of group IDs is passed instead of objects' do
              let(:groups_list) { [sub_group_1.id, sub_group_2.id] }

              it 'returns all requested group IDs with their respective abilities', :aggregate_failures do
                expect(result[sub_group_1.id]).to match_array(expected_abilities)
                expect(result[sub_group_2.id]).to match_array(expected_abilities_2)
              end
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

          context 'when ActiveRecord::Relation of groups is passed' do
            let(:groups_list) { Group.where(id: [sub_group_1.id, sub_group_2.id]) }

            it 'returns all requested group IDs with their respective abilities', :aggregate_failures do
              expect(result[sub_group_1.id]).to match_array(expected_abilities)
              expect(result[sub_group_2.id]).to match_array(expected_abilities_2)
            end
          end

          context 'when nil groups are passed' do
            let(:groups_list) { nil }

            it 'returns an empty hash' do
              expect(result).to eq({})
            end
          end

          context 'when nil user is passed' do
            let(:user) { nil }

            it 'returns an empty hash' do
              expect(result).to eq({})
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

    context 'when an array of group IDs is passed instead of objects' do
      let(:groups_list) { [sub_group_1.id, sub_group_2.id] }

      it_behaves_like 'returns expected member role abilities'
    end
  end

  context 'when multiple groups are invited with custom roles' do
    let_it_be(:source) { sub_group_1 }

    include_context 'with a user in multiple groups with custom role'

    it_behaves_like 'returns expected member role abilities for the user'

    context 'when an array of group IDs is passed instead of objects' do
      let(:groups_list) { [sub_group_1.id, sub_group_2.id] }

      it_behaves_like 'returns expected member role abilities for the user'
    end
  end

  context 'when track_user_group_member_roles_accuracy feature flag is enabled', :saas do
    let_it_be(:ability) { MemberRole.all_customizable_group_permissions.first }
    let_it_be(:member_role) { create_member_role(group, ability) }
    let_it_be(:expected_abilities) { expected_group_abilities(ability) }

    let(:groups_list) { [sub_group_1] }
    let(:base_log_payload) do
      {
        class: described_class.name,
        event: 'Inaccurate user_group_member_roles data',
        user_id: user.id
      }
    end

    let(:log_payload) do
      base_log_payload.merge({
        group_id: sub_group_1.id,
        permissions: instance_of(String),
        user_group_member_roles_permissions: instance_of(String)
      })
    end

    before do
      stub_feature_flags(track_user_group_member_roles_accuracy: true)

      sub_group_1_member.update!(member_role: member_role)

      allow(Gitlab::AppLogger).to receive(:info)
    end

    # Here, the result will be different because there are no
    # user_group_member_roles records for user i.e.
    # ::Authz::UserGroupMemberRoles::UpdateForGroupService was not run on the
    # user's member record for sub_group_1.
    context 'when result of query using user_group_member_roles table is different' do
      it 'logs' do
        expect(Gitlab::AppLogger).to receive(:info).with({
          **log_payload,
          permissions: expected_abilities.join(', '),
          user_group_member_roles_permissions: ''
        })

        result
      end

      context 'when there are multiple groups with different results' do
        let(:groups_list) { [sub_group_1, sub_group_2] }

        let(:log_payload) do
          base_log_payload.merge({ group_ids: groups_list.map(&:id) })
        end

        before do
          role = create_member_role(group, MemberRole.all_customizable_group_permissions.second)
          sub_group_2_member.update!(member_role: role)
        end

        it 'logs' do
          expect(Gitlab::AppLogger).to receive(:info).with(log_payload)

          result
        end

        it 'does not execute additional queries' do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            described_class.new(groups: [sub_group_1], user: user).execute
          end

          # add with_threshold(1) since
          # group.root_ancestor.should_process_custom_roles? is called for each
          # input group
          expect { result }.to issue_same_number_of_queries_as(control).with_threshold(1)
        end
      end

      context 'when track_user_group_member_roles_accuracy feature flag is disabled' do
        before do
          stub_feature_flags(track_user_group_member_roles_accuracy: false)
        end

        it 'does not log' do
          expect(Gitlab::AppLogger).to receive(:info).once

          result
        end
      end
    end

    context 'when result of query using user_group_member_roles table is the same' do
      before do
        ::Authz::UserGroupMemberRoles::UpdateForGroupService.new(sub_group_1_member).execute
      end

      it 'does not log' do
        expect(Gitlab::AppLogger).to receive(:info).once

        result
      end
    end
  end
end
