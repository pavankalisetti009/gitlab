# frozen_string_literal: true

module Ai
  class UsageEventsFinder
    attr_reader :current_user, :namespace, :from, :to, :events, :users

    def initialize(current_user, from:, to:, events: nil, namespace: nil, users: nil)
      @current_user = current_user
      @namespace = namespace
      @from = from
      @to = to
      @events = events
      @users = users
    end

    def execute
      scope = ::Ai::UsageEvent.in_timeframe(from..to).sort_by_timestamp_id
      scope = scope.with_events(events) if events.present?
      scope = scope.with_users(users) if users.present?
      # Hierarchy must be last because it applies IN optimization
      scope = scope.for_namespace_hierarchy(namespace) if namespace
      scope
    end
  end
end
