# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    module PromotionManagementUtils
      include ::GitlabSubscriptions::SubscriptionHelper
      include ::GitlabSubscriptions::BillableUsersUtils

      def member_promotion_management_enabled?
        return false unless promotion_management_settings_enabled?

        member_promotion_management_feature_available?
      end

      def member_promotion_management_feature_available?
        return false unless promotion_management_feature_flag_enabled?
        return false if gitlab_com_subscription?

        exclude_guests?
      end

      def promotion_management_required_for_role?(new_access_level:, member_role_id: nil)
        return false unless member_promotion_management_enabled?

        sm_billable_role_change?(role: new_access_level, member_role_id: member_role_id)
      end

      private

      def promotion_management_feature_flag_enabled?
        ::Feature.enabled?(:member_promotion_management, type: :beta)
      end

      def promotion_management_settings_enabled?
        ::Gitlab::CurrentSettings.enable_member_promotion_management?
      end

      def exclude_guests?
        License.current&.exclude_guests_from_active_count?
      end
    end
  end
end
