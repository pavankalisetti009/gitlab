# frozen_string_literal: true

module Namespaces
  class SeatsUsageNotificationComponent < ViewComponent::Base
    include Gitlab::Utils::StrongMemoize

    def initialize(context:, current_user:)
      @root_namespace = context.root_ancestor
      @current_user = current_user
    end

    def call
      render component_instance
    end

    def render?
      component_instance.present?
    end

    private

    attr_reader :root_namespace, :current_user

    def component_instance
      return unless owner_of_paid_group?

      all_seats_used_alert_component if reached_seats_limit?
    end

    def all_seats_used_alert_component
      if block_seat_overages?
        return Namespaces::BlockSeatOverages::AllSeatsUsedAlertComponent.new(
          context: root_namespace,
          current_user: current_user
        )
      end

      Namespaces::AllSeatsUsedAlertComponent.new(context: root_namespace)
    end

    def block_seat_overages?
      root_namespace.block_seat_overages?
    end

    def current_subscription
      subscription = root_namespace.gitlab_subscription

      subscription if subscription&.has_a_paid_hosted_plan? && !subscription.expired?
    end
    strong_memoize_attr :current_subscription

    def owner_of_paid_group?
      ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions) &&
        root_namespace.group_namespace? &&
        Ability.allowed?(current_user, :owner_access, root_namespace) &&
        current_subscription.present?
    end

    def reached_seats_limit?
      billable_members_count = root_namespace.billable_members_count_with_reactive_cache

      return false if billable_members_count.blank?

      current_subscription.seats <= billable_members_count
    end
  end
end
