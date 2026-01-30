# frozen_string_literal: true

module Namespaces
  class SeatsUsageNotificationComponent < ViewComponent::Base
    include Gitlab::Utils::StrongMemoize

    def initialize(context:, current_user:)
      @root_namespace = context.root_ancestor
      @current_user = current_user
    end

    def call
      return if component_instance.nil?

      render component_instance
    end

    private

    attr_reader :root_namespace, :current_user

    def component_instance
      return unless owner_of_paid_group?

      return all_seats_used_alert_component if reached_seats_limit?

      approaching_seat_count_threshold_component if seat_count_data.present?
    end

    def all_seats_used_alert_component
      if root_namespace.block_seat_overages?
        return Namespaces::BlockSeatOverages::AllSeatsUsedAlertComponent.new(
          context: root_namespace,
          current_user: current_user
        )
      end

      Namespaces::AllSeatsUsedAlertComponent.new(context: root_namespace)
    end

    def approaching_seat_count_threshold_component
      Namespaces::ApproachingSeatCountThresholdComponent.new(
        context: seat_count_data[:namespace],
        remaining_seat_count: seat_count_data[:remaining_seat_count],
        total_seat_count: seat_count_data[:total_seat_count]
      )
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

    def seat_count_data
      GitlabSubscriptions::Reconciliations::CalculateSeatCountDataService.new(
        namespace: root_namespace,
        user: current_user,
        subscription: current_subscription
      ).execute
    end
    strong_memoize_attr :seat_count_data
  end
end
