# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/sessions/successful_verification', feature_category: :onboarding do
  let_it_be(:user) { create_default(:user, onboarding_in_progress: true) }

  context 'with a user during trial registration', :experiment do
    let(:user) do
      create_default(:user, onboarding_in_progress: true, onboarding_status_initial_registration_type: 'trial')
    end

    before do
      allow(view).to receive(:current_user).and_return(user)
    end

    it 'runs experiment' do
      render

      experiment(:lightweight_trial_registration_redesign, actor: user) do |e|
        expect(e.assigned.name).to eq(:control)
      end
    end
  end
end
