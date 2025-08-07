# frozen_string_literal: true

module Ai
  class UsageEventsFinder
    include Gitlab::Utils::StrongMemoize

    attr_reader :current_user, :resource, :from, :to

    def initialize(current_user, resource:, from:, to:)
      @current_user = current_user
      @resource = resource
      @from = from
      @to = to
    end

    def execute
      return ::Ai::UsageEvent.none unless Ability.allowed?(current_user, :read_enterprise_ai_analytics, resource)

      ::Ai::UsageEvent.in_timeframe(from..to).for_namespace_hierarchy(resource)
    end
  end
end
