# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::RunnerControllers::RotateTokenService, feature_category: :continuous_integration do
  include AdminModeHelper

  let(:runner_controller) { create(:ci_runner_controller) }
  let(:token) { create(:ci_runner_controller_token, runner_controller: runner_controller) }

  describe '#execute' do
    subject(:execute) { described_class.new(token: token, current_user: user).execute }

    context 'when user is admin' do
      let(:user) { create(:admin) }

      before do
        enable_admin_mode!(user)
      end

      it 'revokes the old token and creates a new one' do
        response = execute

        expect(response).to be_success
        expect(token.reload).to be_revoked

        new_token = response.payload
        expect(new_token.runner_controller).to eq(runner_controller)
        expect(new_token.description).to eq(token.description)
        expect(new_token.id).not_to eq(token.id)
        expect(new_token).to be_active
      end

      context 'when token is already revoked' do
        before do
          token.revoke!
        end

        it 'returns an error response' do
          response = execute

          expect(response).to be_error
          expect(response.message).to eq('Token already revoked')
        end
      end

      context 'when old token revocation fails' do
        before do
          allow(token).to receive(:revoke!).and_return(false)
          allow(token).to receive_message_chain(:errors, :full_messages).and_return(['Revocation error'])
        end

        it 'returns an error response and does not create a new token' do
          response = execute

          expect(response).to be_error
          expect(response.message).to eq('Failed to revoke token')
          expect(token.reload).not_to be_revoked
        end
      end

      context 'when new token creation fails' do
        before do
          allow_next_instance_of(::Ci::RunnerControllerToken) do |instance|
            allow(instance).to receive(:save) do
              if instance.new_record?
                instance.errors.add(:base, 'Creation error')
                false
              else
                instance.save!
              end
            end
          end
        end

        it 'returns an error response and does not revoke the old token' do
          response = execute

          expect(response).to be_error
          expect(response.message).to eq('Creation error')
          expect(token.reload).not_to be_revoked
        end
      end
    end

    context 'when user is not admin' do
      let(:user) { create(:user) }

      it 'returns an error response' do
        response = execute

        expect(response).to be_error
        expect(response.message).to eq('Administrator permission is required to revoke this token')
        expect(token.reload).not_to be_revoked
      end
    end
  end
end
