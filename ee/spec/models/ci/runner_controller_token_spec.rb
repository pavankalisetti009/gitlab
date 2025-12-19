# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllerToken, feature_category: :continuous_integration do
  let(:runner_controller) { create(:ci_runner_controller) }

  describe 'associations' do
    it { is_expected.to belong_to(:runner_controller).class_name('Ci::RunnerController') }
  end

  describe 'validations' do
    subject(:token) { create(:ci_runner_controller_token) }

    it { is_expected.to validate_length_of(:description).is_at_most(1024) }
  end

  describe 'token' do
    it 'uses TokenAuthenticatable' do
      expect(described_class.token_authenticatable_fields).to include(:token)
    end

    it 'has the correct token prefix' do
      token = create(:ci_runner_controller_token, runner_controller: runner_controller)

      expect(token.token).to start_with('glrct-')
    end
  end

  describe 'callbacks' do
    it 'calls ensure_token before create' do
      token = build(:ci_runner_controller_token, runner_controller: runner_controller)

      expect(token).to receive(:ensure_token).and_call_original
      token.save!
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, revoked: 1) }
  end

  describe 'scopes' do
    describe '.active' do
      it 'returns only active tokens' do
        active_token = create(:ci_runner_controller_token, status: :active)
        revoked_token = create(:ci_runner_controller_token, status: :revoked)

        expect(described_class.active).to include(active_token)
        expect(described_class.active).not_to include(revoked_token)
      end
    end
  end

  describe '#revoke' do
    it 'sets the status to revoked' do
      token = create(:ci_runner_controller_token, status: :active)
      token.revoke!

      expect(token.status).to eq('revoked')
    end
  end
end
