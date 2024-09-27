# frozen_string_literal: true

module GitlabSubscriptions
  module Members
    class ActivityService
      include ExclusiveLeaseGuard

      def initialize(user, namespace)
        @user = user
        @namespace = namespace&.root_ancestor
      end

      def execute
        return ServiceResponse.error(message: 'Invalid params') unless namespace&.group_namespace? && user

        try_obtain_lease do
          if seat_assignment
            seat_assignment.update!(last_activity_on: Time.current)
          else
            GitlabSubscriptions::SeatAssignment.create!(
              namespace: namespace, user: user, last_activity_on: Time.current
            )
          end
        end

        ServiceResponse.success(message: 'Member activity tracked')
      end

      private

      attr_reader :user, :namespace

      def lease_timeout
        (Time.current.end_of_day - Time.current).to_i
      end

      # Used by ExclusiveLeaseGuard
      # do not update the record, if it has been already updated within the last lease_timeout
      def lease_release?
        false
      end

      def lease_key
        "gitlab_subscriptions:members_activity_event:#{namespace.id}:#{user.id}"
      end

      def seat_assignment
        @seat_assignment ||= GitlabSubscriptions::SeatAssignment.find_by_namespace_and_user(namespace, user)
      end
    end
  end
end
