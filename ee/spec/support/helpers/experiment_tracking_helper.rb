# frozen_string_literal: true

module ExperimentTrackingHelper
  def self.included(base)
    base.extend ClassMethods
  end

  class Event
    def initialize(category, action, kwargs)
      @action = action
      @category = category
      @kwargs = kwargs
    end

    attr_reader :action, :category

    def experiment
      data[:experiment]
    end

    def key
      data[:key]
    end

    def assignment?
      action == :assignment
    end

    def experiment?
      experiment.present?
    end

    def data
      @kwargs[:context]&.first&.to_json.try(:[], :data) || {}
    end
  end

  module ClassMethods
    def tracked_events
      @tracked_events ||= []
    end

    def clear_tracked_events
      tracked_events.clear
    end

    def verify_single_assignment(event)
      return unless event.assignment?

      assignment_events = tracked_events.filter { |e| e.assignment? && e.key.present? }
      assignment_events.each do |e|
        unless e.key == event.key
          raise "#{e.experiment} was segmented twice (multiple assignment keys). #{e.key} and then #{event.key}."
        end
      end
    end
  end

  def tracked_events
    self.class.tracked_events
  end
end

RSpec.configure do |config|
  config.before(:each, :experiment_tracking) do
    self.class.clear_tracked_events

    allow(Gitlab::Tracking).to receive(:event) do |category, action, **kwargs| # rubocop:disable RSpec/ExpectGitlabTracking -- snowplow stubbing wouldn't work here
      event = ExperimentTrackingHelper::Event.new(category, action, kwargs)

      next unless event.experiment?

      self.class.verify_single_assignment(event)
      self.class.tracked_events << event
    end
  end

  config.after(:each, :experiment_tracking) do
    allow(Gitlab::Tracking).to receive(:event).and_call_original # rubocop:disable RSpec/ExpectGitlabTracking -- snowplow stubbing wouldn't work here
  end

  config.include ExperimentTrackingHelper, :experiment_tracking
end
