# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PremiumTrialPositioningExperiment, :experiment, feature_category: :acquisition do
  let(:exp) { experiment(:premium_trial_positioning) }

  context 'with candidate experience' do
    before do
      stub_experiments(premium_trial_positioning: :candidate)
    end

    it 'does not raise' do
      expect(exp).to register_behavior(:candidate).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end

  context 'with control experience' do
    before do
      stub_experiments(premium_trial_positioning: :control)
    end

    it 'does not raise an error' do
      expect(exp).to register_behavior(:control).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end
end
