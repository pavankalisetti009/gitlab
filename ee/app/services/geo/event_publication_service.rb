# frozen_string_literal: true

module Geo
  # Store an event on the database
  #
  # @example Publish an event
  #   @replicable_name [String] the name of the Replicator object sending the event
  #   @event_name [Symbol] one of the supported events for the replicator. Typically: :created, :updated or :deleted
  #   @payload [Hash] contextual data published with the event
  #   @return [ServiceResponse] response containing either the event that was created or an error
  class EventPublicationService
    include ::Gitlab::Geo::LogHelpers

    attr_reader :replicable_name, :event_name, :payload

    def initialize(replicable_name:, event_name:, payload:)
      @replicable_name = replicable_name
      @event_name = event_name
      @payload = payload
    end

    def execute
      return error('::Geo::Event cannot be created on Geo Secondary sites') unless Gitlab::Geo.primary?
      return error('::Geo::Event cannot be sent: there are no secondary sites') unless Gitlab::Geo.secondary_nodes.any?

      event = ::Geo::Event.create!(replicable_name:, event_name:, payload:)

      # Only works with the new geo_events at the moment because we need to know which foreign key to use
      ::Geo::EventLog.create!(geo_event: event)

      ServiceResponse.success(message: '::Geo::Event was successfully created.',
        payload: { event:, replicable_name:, event_name:, payload: })
    rescue ActiveRecord::RecordInvalid, NoMethodError => e
      message = '::Geo::Event could not be created.'
      log_error(message, e, { replicable_name:, event_name:, payload: })

      error(message)
    end

    private

    def error(message)
      ServiceResponse.error(message: message, payload: { replicable_name:, event_name:, payload: })
    end
  end
end
