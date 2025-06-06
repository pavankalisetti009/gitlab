# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightweightTrialRegistrationRedesignExperiment, :experiment, feature_category: :acquisition do
  context 'with candidate experience' do
    before do
      stub_experiments(lightweight_trial_registration_redesign: :candidate)
    end

    it 'does not raise' do
      expect(experiment(:lightweight_trial_registration_redesign)).to register_behavior(:candidate).with(nil)
      expect { experiment(:lightweight_trial_registration_redesign).run }.not_to raise_error
    end
  end

  context 'with control experience' do
    before do
      stub_experiments(lightweight_trial_registration_redesign: :control)
    end

    it 'does not raise an error' do
      expect(experiment(:lightweight_trial_registration_redesign)).to register_behavior(:control).with(nil)
      expect { experiment(:lightweight_trial_registration_redesign).run }.not_to raise_error
    end
  end
end
