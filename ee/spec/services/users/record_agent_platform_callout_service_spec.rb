# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::RecordAgentPlatformCalloutService, :aggregate_failures, feature_category: :activation do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, developers: user) }
    let(:namespace_setting) { group.namespace_settings }

    subject(:execute) { described_class.new(current_user: user, group: group).execute }

    context 'when user has not requested access for this group before' do
      it { is_expected.to be_success }

      it 'creates a new group callout and increments request count' do
        expect do
          execute
        end.to change { user.group_callouts.where(feature_name: 'duo_agent_platform_requested', group: group).count }
                 .from(0).to(1)
                 .and change { namespace_setting.reload.duo_agent_platform_request_count }.by(1)
      end
    end

    context 'when user has already requested access for this group' do
      before do
        user.group_callouts.create!(feature_name: 'duo_agent_platform_requested', group: group)
      end

      it 'returns success response with appropriate message' do
        result = execute

        expect(result).to be_success
        expect(result.message).to eq('Access already requested')
      end

      it 'does not increment request count or create new callout' do
        expect do
          execute
        end.to not_change { namespace_setting.reload.duo_agent_platform_request_count }
                .and not_change { user.group_callouts.count }
      end
    end

    context 'when group callout save fails' do
      before do
        allow_next_instance_of(Users::GroupCallout) do |callout|
          allow(callout).to receive_messages(
            save: false,
            errors: instance_double(ActiveModel::Errors,
              full_messages: ['Feature name has already been taken'])
          )
        end
      end

      it 'returns error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('Failed to request Duo Agent Platform')
      end

      it 'logs error' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)

        execute
      end

      it 'does not increment request count when save fails' do
        expect do
          execute
        end.to not_change { namespace_setting.reload.duo_agent_platform_request_count }
                 .and not_change {
                   user.group_callouts.where(feature_name: 'duo_agent_platform_requested', group: group).count
                 }
      end
    end

    context 'with different users requesting access for the same group' do
      let_it_be(:another_user) { create(:user) }

      before_all do
        group.add_developer(another_user)
      end

      it 'handles multiple users independently' do
        expect { execute }.to change { Users::GroupCallout.count }.by(1)
        expect do
          described_class.new(current_user: another_user, group: group).execute
        end.to change { Users::GroupCallout.count }.by(1)

        expect(user.group_callouts.where(feature_name: 'duo_agent_platform_requested', group: group)).to exist
        expect(another_user.group_callouts.where(feature_name: 'duo_agent_platform_requested', group: group)).to exist
      end
    end

    context 'with same user requesting access for different groups' do
      let_it_be(:another_group) { create(:group, developers: user) }

      it 'handles different groups independently' do
        expect { execute }.to change { Users::GroupCallout.count }.by(1)
        expect do
          described_class.new(current_user: user, group: another_group).execute
        end.to change { Users::GroupCallout.count }.by(1)

        expect(user.group_callouts.where(feature_name: 'duo_agent_platform_requested', group: group)).to exist
        expect(user.group_callouts.where(feature_name: 'duo_agent_platform_requested', group: another_group)).to exist
      end
    end

    context 'when user is not authorized' do
      let_it_be(:user) { create(:user) }

      it 'returns error response with error message' do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('User not authorized to request')
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns error response with error message' do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('User not authorized to request')
      end
    end

    context 'when group is nil' do
      let(:group) { nil }

      it 'returns error response with error message' do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('User not authorized to request')
      end
    end
  end
end
