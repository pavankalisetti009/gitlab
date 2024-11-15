# frozen_string_literal: true

module ComplianceManagement
  module Pipl
    class UserPaidStatusCheckWorker
      include ApplicationWorker

      data_consistency :delayed

      idempotent!
      feature_category :instance_resiliency
      urgency :low

      def perform(user_id)
        @user = User.find_by_id(user_id)

        return unless @user

        if user_subject_to_pipl?
          send_pipl_notification_email
        else
          user.pipl_user.reset_notification!
        end
      end

      private

      attr_reader :user

      # Guests and minimal access users, while treated as non-billables in
      # namespaces under Ultimate plans, are also exempted from actions taken to
      # ensure PIPL compliance
      def paid?
        user.authorized_groups.any? do |group|
          group.root_ancestor.paid?
        end
      end

      def user_subject_to_pipl?
        # This cache value is used to determine if a user is subject to PIPL
        # which qualifies them for certain actions taken for compliance (e.g.
        # banner and email notifications, etc.).

        Rails.cache.fetch([PIPL_SUBJECT_USER_CACHE_KEY, user.id], expires_in: 24.hours) do
          !paid?
        end
      end

      def send_pipl_notification_email
        ComplianceManagement::Pipl::SendInitialComplianceEmailService.new(user: user).execute
      end
    end
  end
end
