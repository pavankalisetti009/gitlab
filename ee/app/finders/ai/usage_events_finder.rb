# frozen_string_literal: true

module Ai
  class UsageEventsFinder
    include Gitlab::Utils::StrongMemoize

    attr_reader :current_user, :resource, :from, :to, :events

    def initialize(current_user, resource:, from:, to:, events: nil)
      @current_user = current_user
      @resource = resource
      @from = from
      @to = to
      @events = events
    end

    def execute
      return ::Ai::UsageEvent.none unless Ability.allowed?(current_user, :read_enterprise_ai_analytics, resource)

      scope = ::Ai::UsageEvent.in_timeframe(from..to).for_namespace_hierarchy(resource)
      scope = scope.with_events(events) if events.present?
      scope
    end
  end
end
