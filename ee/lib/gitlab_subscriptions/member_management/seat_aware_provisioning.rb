# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    module SeatAwareProvisioning
      def calculate_adjusted_access_level(source, invitee, requested_access_level, extra = {})
        adjusted_access_level = adjust_access_level_for_seat_availability(source, invitee, requested_access_level)

        if adjusted_access_level != requested_access_level
          log_bso_access_level_adjustment(source, invitee, requested_access_level, adjusted_access_level, extra)
        end

        adjusted_access_level
      end

      private

      def adjust_access_level_for_seat_availability(source, invitee, desired_access_level)
        return desired_access_level unless feature_flag_enabled?(source)
        return desired_access_level unless apply_bso_adjustment?(source)
        return desired_access_level if seats_available_for_desired_access?(source, invitee, desired_access_level)

        ::Gitlab::Access::MINIMAL_ACCESS
      end

      def feature_flag_enabled?(source)
        if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          ::Feature.enabled?(:bso_minimal_access_fallback, source.root_ancestor)
        else
          ::Feature.enabled?(:bso_minimal_access_fallback, :instance)
        end
      end

      def apply_bso_adjustment?(source)
        ::GitlabSubscriptions::MemberManagement::BlockSeatOverages.block_seat_overages?(source)
      end

      def seats_available_for_desired_access?(source, invitee, access_level)
        user_identifier = invitee.is_a?(User) ? invitee.id : invitee

        ::GitlabSubscriptions::MemberManagement::BlockSeatOverages.seats_available_for?(
          source, [user_identifier], access_level, nil
        )
      end

      def log_bso_access_level_adjustment(source, invitee, requested_access_level, adjusted_access_level, extra = {})
        user = invitee.is_a?(User) ? invitee : nil

        log_data = {
          message: 'Group membership access level adjusted due to BSO seat limits',
          group_id: source.id,
          group_path: source.full_path,
          user_id: user&.id,
          requested_access_level: requested_access_level,
          adjusted_access_level: adjusted_access_level,
          feature_flag: 'bso_minimal_access_fallback'
        }.merge(extra)

        ::Gitlab::AppLogger.info(log_data)
      end
    end
  end
end
