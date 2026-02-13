# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::TrialUserConstraint, feature_category: :onboarding do
  subject(:constraint) { described_class.new }

  let(:user) { nil }
  let(:warden) { instance_double(Warden::Proxy, user: user) }
  let(:request) do
    env = Rack::MockRequest.env_for('/', method: 'GET')
    env['warden'] = warden
    ActionDispatch::Request.new(env)
  end

  describe '#matches?' do
    context 'when user is not present' do
      it 'returns false' do
        expect(constraint.matches?(request)).to be(false)
      end
    end

    context 'when user is present' do
      let_it_be(:user, reload: true) { create(:user) }

      context 'when user is not a trial user' do
        before do
          stub_experiments(lightweight_trial_registration_redesign: :candidate)
        end

        it 'returns false' do
          expect(constraint.matches?(request)).to be(false)
        end
      end

      context 'when user is a trial user' do
        before do
          user.update!(onboarding_status_registration_type: ::Onboarding::REGISTRATION_TYPE[:trial])
        end

        context 'when lightweight_trial_registration_redesign is candidate' do
          before do
            stub_experiments(lightweight_trial_registration_redesign: :candidate)
          end

          it 'is truthy' do
            expect(constraint.matches?(request)).to be_truthy
          end
        end

        context 'when lightweight_trial_registration_redesign is control' do
          before do
            stub_experiments(lightweight_trial_registration_redesign: :control)
          end

          it 'is false' do
            expect(constraint.matches?(request)).to be(false)
          end
        end
      end
    end
  end
end
