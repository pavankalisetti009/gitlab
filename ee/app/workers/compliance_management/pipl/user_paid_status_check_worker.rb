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

        # This cache value is used to determine if a user is subject to PIPL
        # which qualifies them for certain actions taken for compliance (e.g.
        # banner and email notifications, etc.).
        Rails.cache.fetch([PIPL_SUBJECT_USER_CACHE_KEY, user.id], expires_in: 24.hours) do
          !paid?
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
    end
  end
end
