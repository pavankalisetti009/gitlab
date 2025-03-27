# frozen_string_literal: true

module EE
  module Members
    module ApproveAccessRequestService
      extend ::Gitlab::Utils::Override
      include ::GitlabSubscriptions::MemberManagement::PromotionManagementUtils

      def after_execute(member:, skip_log_audit_event: false)
        super

        log_audit_event(member: member) unless skip_log_audit_event
      end

      private

      override :limit_to_guest_if_billable_promotion_restricted
      def limit_to_guest_if_billable_promotion_restricted(access_requester)
        return if current_user.present? && current_user.can_admin_all_resources?

        return unless member_promotion_management_enabled? &&
          ::User.non_billable_users_for_billable_management([access_requester.user.id]).present? &&
          promotion_management_required_for_role?(new_access_level: access_requester.access_level)

        access_requester.access_level = ::Gitlab::Access::GUEST
      end

      override :can_approve_access_requester?
      def can_approve_access_requester?(access_requester)
        super && !member_role_too_high?(access_requester)
      end

      def member_role_too_high?(access_requester)
        access_requester.prevent_role_assignement?(current_user, params)
      end

      def log_audit_event(member:)
        audit_context = {
          name: 'member_created',
          author: current_user || ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)'),
          scope: member.source,
          target: member.user || ::Gitlab::Audit::NullTarget.new,
          target_details: member.user&.name || 'Created User',
          message: 'Membership created',
          additional_details: {
            add: 'user_access',
            as: member.human_access_labeled,
            member_id: member.id
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
