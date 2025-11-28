# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ExperimentTrackingHelper, feature_category: :acquisition do
  describe 'tracking events in specs', :experiment_tracking do
    it 'captures tracking events' do
      context = [SnowplowTracker::SelfDescribingJson.new("schema name", {
        variant: "candidate",
        experiment: "experiment_name",
        key: "key-ident"
      })]
      Gitlab::Tracking.event('experiment_name', :assignment, context: context)

      event = tracked_events.first
      expect(event.experiment?).to be(true)
      expect(event.experiment).to eq("experiment_name")
      expect(event.action).to eq(:assignment)
      expect(event.key).to eq("key-ident")
    end

    it 'captures tracking events' do
      context = [SnowplowTracker::SelfDescribingJson.new("schema name", { experiment: "experiment_name" })]
      Gitlab::Tracking.event('experiment_name', :assignment, context: context)
      Gitlab::Tracking.event('new_category', 'new_action')

      expect(tracked_events.count).to eq(1)
    end

    it 'clears events between examples' do
      expect(tracked_events).to be_empty
    end

    it 'captures tracking events' do
      context = [SnowplowTracker::SelfDescribingJson.new("schema name", {
        variant: "candidate",
        experiment: "experiment_name",
        key: "key-ident"
      })]
      context_2 = [SnowplowTracker::SelfDescribingJson.new("schema name", {
        variant: "candidate",
        experiment: "experiment_name",
        key: "key-ident-2"
      })]
      Gitlab::Tracking.event('experiment_name', :assignment, context: context)

      expect do
        Gitlab::Tracking.event('experiment_name', :assignment, context: context_2)
      end.to raise_error "experiment_name was segmented 2 times (expected 1) - key-ident, key-ident-2."
    end
  end
end
