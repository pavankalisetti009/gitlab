# frozen_string_literal: true

module GitlabSubscriptions
  module Members
    class DestroyedWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :delayed
      feature_category :seat_cost_management
      urgency :low
      idempotent!
      deduplicate :until_executed

      def handle_event(event)
        user = ::User.find_by_id(event.data[:user_id])
        namespace = ::Namespace.find_by_id(event.data[:root_namespace_id])

        return unless user && namespace&.group_namespace?

        seat = GitlabSubscriptions::SeatAssignment.find_by_namespace_and_user(namespace, user)

        return unless seat

        highest_access_level = ::Member.in_hierarchy(namespace).with_user(user)
                                       .without_invites_and_requests(minimal_access: true).maximum(:access_level)

        if highest_access_level.nil?
          seat.destroy!
        elsif free_seat?(highest_access_level, namespace)
          seat.update!(seat_type: :free)
        else
          seat.update!(seat_type: :base)
        end
      end

      private

      def free_seat?(access_level, namespace)
        (namespace.exclude_guests? && access_level == ::Gitlab::Access::GUEST) ||
          access_level == ::Gitlab::Access::MINIMAL_ACCESS
      end
    end
  end
end
