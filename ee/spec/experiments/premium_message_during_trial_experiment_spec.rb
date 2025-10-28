# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PremiumMessageDuringTrialExperiment, :experiment, feature_category: :acquisition do
  let(:exp) { experiment(:premium_message_during_trial) }

  context 'with candidate experience' do
    before do
      stub_experiments(premium_message_during_trial: :candidate)
    end

    it 'does not raise an error' do
      expect(exp).to register_behavior(:candidate).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end

  context 'with control experience' do
    before do
      stub_experiments(premium_message_during_trial: :control)
    end

    it 'does not raise an error' do
      expect(exp).to register_behavior(:control).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end
end
