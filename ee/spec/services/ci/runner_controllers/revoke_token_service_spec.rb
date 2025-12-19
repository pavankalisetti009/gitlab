# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::RevokeTokenService, feature_category: :continuous_integration do
  include AdminModeHelper

  let(:runner_controller) { create(:ci_runner_controller) }
  let(:runner_controller_token) { create(:ci_runner_controller_token, runner_controller: runner_controller) }
  let(:admin_user) { create(:admin) }
  let(:non_admin_user) { create(:user) }

  describe '#execute' do
    subject(:execute) { described_class.new(token: runner_controller_token, current_user: current_user).execute }

    context 'when the user is an admin' do
      let(:current_user) { admin_user }

      before do
        enable_admin_mode!(current_user)
      end

      it 'successfully revokes the token' do
        execute

        expect(runner_controller_token.reload.revoked?).to be true
      end

      it 'returns a success response' do
        response = execute

        expect(response).to be_success
      end

      context 'when it fails' do
        before do
          allow(runner_controller_token).to receive(:revoke!).and_return(false)
          allow(runner_controller_token).to receive_message_chain(:errors, :full_messages).and_return(['Some error'])
        end

        it 'returns an error response' do
          response = execute

          expect(response).to be_error
          expect(response.message).to eq(['Some error'])
        end
      end
    end

    context 'when the user is not an admin' do
      let(:current_user) { non_admin_user }

      it 'returns an error response indicating insufficient permissions' do
        response = execute

        expect(response).to be_error
        expect(response.message).to eq('Administrator permission is required to revoke this token')
      end

      it 'does not revoke the token' do
        execute

        expect(runner_controller_token.reload.active?).to be true
      end
    end
  end
end
