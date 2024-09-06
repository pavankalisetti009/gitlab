# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Export::DetailedDataService, feature_category: :system_access do
  include_context 'with group members shared context'

  let(:current_user) { users[0] }
  let(:requested_group) { group }

  subject(:export) { described_class.new(container: requested_group, current_user: current_user).execute }

  shared_examples 'not available' do
    it 'returns a failed response' do
      response = export

      expect(response).not_to be_success
      expect(response.message).to eq('Not available')
    end
  end

  describe '#execute' do
    context 'when unlicensed' do
      before do
        stub_licensed_features(export_user_permissions: false)
      end

      it_behaves_like 'not available'
    end

    context 'when licensed' do
      before do
        stub_licensed_features(export_user_permissions: true)
      end

      context 'when current_user is a group maintainer' do
        let(:current_user) { users[1] }

        it_behaves_like 'not available'
      end

      context 'when current user is a group owner' do
        shared_examples 'exporting correct data' do
          it 'is successful' do
            expect(export).to be_success
          end

          it 'returns correct data' do
            headers = ['Name', 'Username', 'Email', 'Path', 'Role', 'Membership type', 'Membership source',
              'Access granted', 'Access expired', 'Last activity']

            expect(data).to match_array([headers] + expected_result)
          end

          it 'avoids N+1 queries' do
            count = ActiveRecord::QueryRecorder.new { export }

            create(:group_member, :owner, group: requested_group, user: create(:user))

            expect { described_class.new(container: requested_group, current_user: current_user).execute }
              .not_to exceed_query_limit(count).with_threshold(1)
          end
        end

        let(:data) { CSV.parse(export.payload) }
        let(:group_members) do
          [
            user_data(0) + [group.full_path, 'Owner', 'direct', group.full_path] + member_data(group_owner_1),
            user_data(1) + [group.full_path, 'Maintainer', 'direct', group.full_path] + member_data(group_maintainer_2),
            user_data(2) + [group.full_path, 'Developer', 'direct', group.full_path] + member_data(group_developer_3)
          ]
        end

        let(:sub_group_1_members) do
          [
            user_data(1) + [sub_group_1.full_path, 'Owner', 'direct',
              sub_group_1.full_path] + member_data(sub_group_1_owner_2),
            user_data(0) + [sub_group_1.full_path, 'Owner', 'inherited', group.full_path] + member_data(group_owner_1),
            user_data(2) + [sub_group_1.full_path, 'Developer', 'inherited',
              group.full_path] + member_data(group_developer_3),
            user_data(4) + [sub_group_1.full_path, 'Developer', 'shared',
              shared_group.full_path] + member_data(shared_maintainer_5),
            user_data(5) + [sub_group_1.full_path, 'Developer', 'shared',
              shared_group.full_path] + member_data(shared_maintainer_6)
          ]
        end

        let(:sub_group_2_members) do
          [
            user_data(0) + [sub_group_2.full_path, 'Owner', 'inherited', group.full_path] + member_data(group_owner_1),
            user_data(1) + [sub_group_2.full_path, 'Maintainer', 'inherited',
              group.full_path] + member_data(group_maintainer_2),
            user_data(2) + [sub_group_2.full_path, 'Developer', 'inherited',
              group.full_path] + member_data(group_developer_3)
          ]
        end

        let(:sub_sub_group_1_members) do
          [
            user_data(3) + [sub_sub_group_1.full_path, 'Owner', 'direct',
              sub_sub_group_1.full_path] + member_data(sub_sub_group_owner_4),
            user_data(4) + [sub_sub_group_1.full_path, 'Owner', 'direct',
              sub_sub_group_1.full_path] + member_data(sub_sub_group_owner_5),
            user_data(0) + [sub_sub_group_1.full_path, 'Owner', 'inherited',
              group.full_path] + member_data(group_owner_1),
            user_data(1) + [sub_sub_group_1.full_path, 'Owner', 'inherited',
              sub_group_1.full_path] + member_data(sub_group_1_owner_2),
            user_data(2) + [sub_sub_group_1.full_path, 'Developer', 'inherited',
              group.full_path] + member_data(group_developer_3),
            user_data(5) + [sub_sub_group_1.full_path, 'Developer', 'shared',
              shared_group.full_path] + member_data(shared_maintainer_6)
          ]
        end

        let(:sub_sub_sub_group_1_members) do
          [
            user_data(0) + [sub_sub_sub_group_1.full_path, 'Owner', 'inherited',
              group.full_path] + member_data(group_owner_1),
            user_data(1) + [sub_sub_sub_group_1.full_path, 'Owner', 'inherited',
              sub_group_1.full_path] + member_data(sub_group_1_owner_2),
            user_data(2) + [sub_sub_sub_group_1.full_path, 'Developer', 'inherited',
              group.full_path] + member_data(group_developer_3),
            user_data(3) + [sub_sub_sub_group_1.full_path, 'Owner', 'inherited',
              sub_sub_group_1.full_path] + member_data(sub_sub_group_owner_4),
            user_data(4) + [sub_sub_sub_group_1.full_path, 'Owner', 'inherited',
              sub_sub_group_1.full_path] + member_data(sub_sub_group_owner_5),
            user_data(5) + [sub_sub_sub_group_1.full_path, 'Developer', 'shared',
              shared_group.full_path] + member_data(shared_maintainer_6)
          ]
        end

        def user_data(user_id)
          user = users[user_id]

          [user.name, user.username, user.email]
        end

        def member_data(member)
          [member.created_at.to_fs(:csv), nil, member.reload.last_activity_on.to_fs(:csv)]
        end

        context 'when members_permissions_detailed_export feature flag is disabled' do
          before do
            stub_feature_flags(members_permissions_detailed_export: false)
          end

          it_behaves_like 'not available'
        end

        context 'when members_permissions_detailed_export feature flag is enabled' do
          before do
            stub_feature_flags(members_permissions_detailed_export: true)
          end

          context 'for group' do
            let(:requested_group) { group }
            let(:expected_result) do
              group_members + sub_group_1_members + sub_group_2_members +
                sub_sub_group_1_members + sub_sub_sub_group_1_members
            end

            it_behaves_like 'exporting correct data'
          end

          context 'for subgroup' do
            let(:requested_group) { sub_group_1 }
            let(:expected_result) { sub_group_1_members + sub_sub_group_1_members + sub_sub_sub_group_1_members }

            it_behaves_like 'exporting correct data'
          end

          context 'for sub_sub_group' do
            let(:requested_group) { sub_sub_group_1 }
            let(:expected_result) { sub_sub_group_1_members + sub_sub_sub_group_1_members }

            it_behaves_like 'exporting correct data'
          end

          context 'for sub_sub_sub_group_1' do
            let(:requested_group) { sub_sub_sub_group_1 }
            let(:expected_result) { sub_sub_sub_group_1_members }

            it_behaves_like 'exporting correct data'
          end
        end
      end
    end
  end
end
