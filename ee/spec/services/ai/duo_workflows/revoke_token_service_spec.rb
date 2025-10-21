# frozen_string_literal: true

require 'spec_helper'
RSpec.describe ::Ai::DuoWorkflows::RevokeTokenService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:another_user) { create(:user) }

    it 'returns success when token to revoke is invalid' do
      result = described_class.new(token: "not-a-valid-token", current_user: user).execute

      expect(result[:status]).to eq(:success)
    end

    it 'returns error when token to revoke does not belong to current user' do
      token = create(:oauth_access_token, user: another_user, scopes: ['ai_workflows'])

      result = described_class.new(token: token.plaintext_token, current_user: user).execute

      expect(result[:status]).to eq(:error)
      expect(result[:reason]).to eq(:forbidden)
      expect(token.reload.revoked?).to be(false)
    end

    it 'returns error when token to revoke does not have ai_workflows scope' do
      token = create(:oauth_access_token, user: user, scopes: ['api'])

      result = described_class.new(token: token.plaintext_token, current_user: user).execute

      expect(result[:status]).to eq(:error)
      expect(result[:reason]).to eq(:forbidden)
      expect(token.reload.revoked?).to be(false)
    end

    it 'returns error when token could not be revoked' do
      token = create(:oauth_access_token, user: user, scopes: ['ai_workflows'])

      allow(Doorkeeper::AccessToken).to receive(:by_token).with(token.plaintext_token).and_return(token)
      allow(token).to receive(:revoke).and_return(false)

      result = described_class.new(token: token.plaintext_token, current_user: user).execute

      expect(result[:status]).to eq(:error)
      expect(result[:reason]).to eq(:unprocessable_entity)
      expect(token.reload.revoked?).to be(false)
    end

    it 'returns success when token could be revoked' do
      token = create(:oauth_access_token, user: user, scopes: ['ai_workflows'])

      result = described_class.new(token: token.plaintext_token, current_user: user).execute

      expect(result[:status]).to eq(:success)
      expect(token.reload.revoked?).to be(true)
    end
  end
end
