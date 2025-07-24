# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightweightTrialRegistrationRedesignExperiment, :experiment, feature_category: :acquisition do
  let_it_be(:user, reload: true) { create_default(:user, onboarding_in_progress: true) }

  let(:exp) { experiment(:lightweight_trial_registration_redesign) }

  context 'with candidate experience' do
    before do
      stub_experiments(lightweight_trial_registration_redesign: :candidate)
    end

    it 'does not raise' do
      expect(exp).to register_behavior(:candidate).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end

  context 'with control experience' do
    before do
      stub_experiments(lightweight_trial_registration_redesign: :control)
    end

    it 'does not raise an error' do
      expect(exp).to register_behavior(:control).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end

  context "for excludes" do
    it "non trial registrations" do
      user.update!(onboarding_status_initial_registration_type: 'non-trial')
      expect(exp).to exclude(actor: user)
    end
  end

  context "for includes" do
    it "user who isn't signed in" do
      expect(exp).not_to exclude(actor: "UNIQUE_ID")
    end

    it "not yet determined trial registration types" do
      user.update!(
        onboarding_status_initial_registration_type: nil)
      expect(exp).not_to exclude(actor: user)
    end

    it "not yet created user" do
      expect(exp).not_to exclude(actor: nil)
    end
  end
end
