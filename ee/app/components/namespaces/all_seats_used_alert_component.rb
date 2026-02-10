# frozen_string_literal: true

module Namespaces
  class AllSeatsUsedAlertComponent < ViewComponent::Base
    def initialize(context:)
      @root_namespace = context.root_ancestor
    end

    private

    attr_reader :root_namespace

    def render?
      Feature.enabled?(:notify_all_seats_used, root_namespace, type: :wip) && !root_namespace.free_plan?
    end
  end
end
