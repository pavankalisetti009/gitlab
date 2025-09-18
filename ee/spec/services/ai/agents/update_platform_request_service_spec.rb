# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Agents::UpdatePlatformRequestService, :aggregate_failures, feature_category: :activation do
  describe '#execute' do
    let_it_be(:user) { create(:user) }

    before_all do
      create(:ai_settings, duo_agent_platform_request_count: 0)
    end

    subject(:execute) { described_class.new(user).execute }

    context 'when user has not requested access before' do
      it { is_expected.to be_success }

      it 'creates a new callout and increments request count' do
        expect { execute }
          .to change { user.callouts.where(feature_name: 'duo_agent_platform_requested').count }
                .from(0).to(1)
                .and change { ::Ai::Setting.instance.duo_agent_platform_request_count }
                       .by(1)
      end
    end

    context 'when user has already requested access' do
      before do
        user.callouts.create!(feature_name: 'duo_agent_platform_requested')
      end

      it 'returns success response' do
        expect(execute).to be_success
        expect(execute.message).to eq('Access already requested')
      end

      it 'does not increment request count' do
        expect { execute }
          .to not_change { ::Ai::Setting.instance.duo_agent_platform_request_count }
                .and not_change { user.callouts.count }
      end
    end

    context 'when callout save fails' do
      before do
        allow_next_instance_of(Users::Callout) do |callout|
          allow(callout).to receive_messages(save: false,
            errors: instance_double(ActiveModel::Errors, full_messages: ['Feature name has already been taken']))
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
        expect { execute }
          .to not_change { ::Ai::Setting.instance.duo_agent_platform_request_count }
                .and not_change { user.callouts.where(feature_name: 'duo_agent_platform_requested').count }
      end
    end

    context 'with different users requesting access' do
      let_it_be(:another_user) { create(:user) }

      it 'handles multiple users independently' do
        result1 = described_class.new(user).execute
        expect(result1).to be_success

        result2 = described_class.new(another_user).execute
        expect(result2).to be_success

        expect(user.callouts.where(feature_name: 'duo_agent_platform_requested')).to exist
        expect(another_user.callouts.where(feature_name: 'duo_agent_platform_requested')).to exist

        expect(::Ai::Setting.instance.duo_agent_platform_request_count).to eq(2)
      end
    end

    context 'when user is nil' do
      subject(:execute) { described_class.new(nil).execute }

      it 'raises an error when trying to access current_user' do
        expect { execute }.to raise_error(NoMethodError)
      end
    end
  end
end
