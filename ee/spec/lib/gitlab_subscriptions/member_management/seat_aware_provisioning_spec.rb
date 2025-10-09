# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::SeatAwareProvisioning, feature_category: :seat_cost_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:test_class) do
    Class.new do
      include GitlabSubscriptions::MemberManagement::SeatAwareProvisioning
    end
  end

  let(:instance) { test_class.new }

  describe '#calculate_adjusted_access_level' do
    let(:desired_access) { Gitlab::Access::DEVELOPER }

    subject(:result) do
      instance.calculate_adjusted_access_level(group, user, desired_access)
    end

    context 'when on saas', :saas do
      before do
        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:seats_available_for?)
      end

      it 'returns desired access level unchanged' do
        expect(result).to eq(desired_access)
        expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .not_to have_received(:seats_available_for?)
      end
    end

    context 'when BSO is not enabled' do
      before do
        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:block_seat_overages?).with(group).and_return(false)
        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:seats_available_for?)
      end

      it 'returns desired access level unchanged' do
        expect(result).to eq(desired_access)
        expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .not_to have_received(:seats_available_for?)
      end
    end

    context 'when BSO is enabled' do
      before do
        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:block_seat_overages?).with(group).and_return(true)
      end

      context 'when seats are available' do
        before do
          allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to receive(:seats_available_for?).and_return(true)
        end

        it 'returns desired access level' do
          expect(result).to eq(desired_access)
          expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to have_received(:seats_available_for?)
            .with(group, [user.id], desired_access, nil)
        end

        it 'does not log access level adjustment' do
          allow(Gitlab::AppLogger).to receive(:info)

          result

          expect(Gitlab::AppLogger).not_to have_received(:info).with(
            hash_including(message: 'Group membership access level adjusted due to BSO seat limits')
          )
        end
      end

      context 'when seats are not available' do
        before do
          allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to receive(:seats_available_for?).and_return(false)
        end

        context 'with bso_minimal_access_fallback feature flag enabled' do
          before do
            stub_feature_flags(bso_minimal_access_fallback: true)
          end

          it 'returns minimal access' do
            expect(result).to eq(Gitlab::Access::MINIMAL_ACCESS)
            expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
              .to have_received(:seats_available_for?)
              .with(group, [user.id], desired_access, nil)
          end

          it 'logs the access level adjustment' do
            allow(Gitlab::AppLogger).to receive(:info)

            result

            expect(Gitlab::AppLogger).to have_received(:info).with(
              hash_including(
                message: 'Group membership access level adjusted due to BSO seat limits',
                group_id: group.id,
                group_path: group.full_path,
                user_id: user.id,
                requested_access_level: desired_access,
                adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
                feature_flag: 'bso_minimal_access_fallback'
              )
            )
          end

          it 'logs the access level adjustment with extra parameters' do
            allow(Gitlab::AppLogger).to receive(:info)

            instance.calculate_adjusted_access_level(group, user, desired_access, { scim_group_uid: 'test-uid' })

            expect(Gitlab::AppLogger).to have_received(:info).with(
              hash_including(
                message: 'Group membership access level adjusted due to BSO seat limits',
                group_id: group.id,
                group_path: group.full_path,
                user_id: user.id,
                requested_access_level: desired_access,
                adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
                feature_flag: 'bso_minimal_access_fallback',
                scim_group_uid: 'test-uid'
              )
            )
          end
        end

        context 'with bso_minimal_access_fallback feature flag disabled' do
          before do
            stub_feature_flags(bso_minimal_access_fallback: false)
          end

          it 'returns desired access level' do
            expect(result).to eq(desired_access)
            expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
              .not_to have_received(:seats_available_for?)
          end
        end
      end
    end

    context 'with email invitee' do
      let(:email) { 'test@example.com' }

      subject(:result) do
        instance.calculate_adjusted_access_level(group, email, desired_access)
      end

      before do
        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:block_seat_overages?).with(group).and_return(true)
        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:seats_available_for?).and_return(false)
      end

      context 'when seats are available' do
        before do
          allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to receive(:seats_available_for?).and_return(true)
        end

        it 'returns desired access level' do
          expect(result).to eq(desired_access)
          expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to have_received(:seats_available_for?)
            .with(group, [email], desired_access, nil)
        end
      end

      context 'with bso_minimal_access_fallback feature flag enabled' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: true)
        end

        it 'handles email invitees correctly' do
          expect(result).to eq(Gitlab::Access::MINIMAL_ACCESS)
          expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to have_received(:seats_available_for?)
            .with(group, [email], desired_access, nil)
        end

        it 'logs the access level adjustment with email invitee' do
          allow(Gitlab::AppLogger).to receive(:info)

          result

          expect(Gitlab::AppLogger).to have_received(:info).with(
            hash_including(
              message: 'Group membership access level adjusted due to BSO seat limits',
              group_id: group.id,
              group_path: group.full_path,
              user_id: nil,
              requested_access_level: desired_access,
              adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
              feature_flag: 'bso_minimal_access_fallback'
            )
          )
        end
      end

      context 'with bso_minimal_access_fallback feature flag disabled' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: false)
        end

        it 'returns desired access level' do
          expect(result).to eq(desired_access)
          expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .not_to have_received(:seats_available_for?)
        end
      end
    end
  end
end
