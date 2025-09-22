# frozen_string_literal: true

module AuditEvents
  class ExternalDestinationStreamer
    attr_reader :event_name, :audit_event

    STRATEGIES = [
      AuditEvents::Strategies::GroupExternalDestinationStrategy,
      AuditEvents::Strategies::InstanceExternalDestinationStrategy,
      AuditEvents::Strategies::GoogleCloudLoggingDestinationStrategy,
      AuditEvents::Strategies::Instance::GoogleCloudLoggingDestinationStrategy,
      AuditEvents::Strategies::AmazonS3DestinationStrategy,
      AuditEvents::Strategies::Instance::AmazonS3DestinationStrategy
    ].freeze

    def initialize(event_name, audit_event)
      @event_name = event_name
      @audit_event = audit_event
    end

    def stream_to_destinations
      if streamers.any?(&:streamable?)
        streamers.each(&:execute)
      else
        streamable_strategies.each(&:execute)
      end
    end

    def streamable?
      streamers.any?(&:streamable?) || streamable_strategies.any?
    end

    private

    def streamers
      @streamers ||= [
        AuditEvents::Streaming::Group::Streamer.new(event_name, audit_event),
        AuditEvents::Streaming::Instance::Streamer.new(event_name, audit_event)
      ]
    end

    def streamable_strategies
      @streamable_strategies ||= STRATEGIES.filter_map do |strategy|
        strategy_instance = strategy.new(event_name, audit_event)
        strategy_instance if strategy_instance.streamable?
      end
    end
  end
end
