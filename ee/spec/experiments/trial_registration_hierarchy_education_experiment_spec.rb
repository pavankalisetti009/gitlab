# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TrialRegistrationHierarchyEducationExperiment, :experiment, feature_category: :acquisition do
  let(:exp) { experiment(:trial_registration_hierarchy_education) }

  context 'with candidate experience' do
    before do
      stub_experiments(trial_registration_hierarchy_education: :candidate)
    end

    it 'does not raise' do
      expect(exp).to register_behavior(:candidate).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end

  context 'with control experience' do
    before do
      stub_experiments(trial_registration_hierarchy_education: :control)
    end

    it 'does not raise an error' do
      expect(exp).to register_behavior(:control).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end
end
