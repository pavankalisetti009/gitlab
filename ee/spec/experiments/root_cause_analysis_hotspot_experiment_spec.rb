# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RootCauseAnalysisHotspotExperiment, :experiment, feature_category: :activation do
  context 'with control experience' do
    before do
      stub_experiments(root_cause_analysis_hotspot: :control)
    end

    it 'registers control behavior' do
      expect(experiment(:root_cause_analysis_hotspot)).to register_behavior(:control).with(nil)
      expect { experiment(:root_cause_analysis_hotspot).run }.not_to raise_error
    end
  end

  context 'with candidate experience' do
    before do
      stub_experiments(root_cause_analysis_hotspot: :candidate)
    end

    it 'registers candidate behavior' do
      expect(experiment(:root_cause_analysis_hotspot)).to register_behavior(:candidate).with(nil)
      expect { experiment(:root_cause_analysis_hotspot).run }.not_to raise_error
    end
  end
end
