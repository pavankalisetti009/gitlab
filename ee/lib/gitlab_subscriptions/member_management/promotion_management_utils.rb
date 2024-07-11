# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    module PromotionManagementUtils
      include ::GitlabSubscriptions::SubscriptionHelper
      include ::GitlabSubscriptions::BillableUsersUtils

      def promotion_management_applicable?
        return false unless promotion_management_active?
        return false unless promotion_management_available?

        true
      end

      def promotion_management_available?
        return false unless promotion_management_feature_enabled?
        return false if gitlab_com_subscription?
        return false unless exclude_guests?

        true
      end

      def promotion_management_required_for_role?(new_access_level:, member_role_id: nil)
        return false unless promotion_management_applicable?

        sm_billable_role_change?(role: new_access_level, member_role_id: member_role_id)
      end

      private

      def promotion_management_feature_enabled?
        ::Feature.enabled?(:member_promotion_management, type: :wip)
      end

      def promotion_management_active?
        ::Gitlab::CurrentSettings.enable_member_promotion_management?
      end

      def exclude_guests?
        License.current&.exclude_guests_from_active_count?
      end
    end
  end
end
