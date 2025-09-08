# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    module SeatAwareProvisioning
      def adjust_access_level_for_seat_availability(source, invitee, desired_access_level)
        return desired_access_level if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        return desired_access_level unless apply_bso_adjustment?(source)
        return desired_access_level if seats_available_for_desired_access?(source, invitee, desired_access_level)

        ::Gitlab::Access::MINIMAL_ACCESS
      end

      private

      def apply_bso_adjustment?(source)
        return false unless ::Feature.enabled?(:bso_minimal_access_fallback, :instance)

        ::GitlabSubscriptions::MemberManagement::BlockSeatOverages.block_seat_overages?(source)
      end

      def seats_available_for_desired_access?(source, invitee, access_level)
        user_identifier = invitee.is_a?(User) ? invitee.id : invitee

        ::GitlabSubscriptions::MemberManagement::BlockSeatOverages.seats_available_for?(
          source, [user_identifier], access_level, nil
        )
      end
    end
  end
end
