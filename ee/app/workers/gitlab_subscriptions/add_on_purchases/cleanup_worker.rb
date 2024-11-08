# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    class CleanupWorker
      include ApplicationWorker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- Context unnecessary

      data_consistency :sticky
      feature_category :subscription_management
      idempotent!

      def perform
        GitlabSubscriptions::AddOnPurchase
          .includes(:add_on, :assigned_users, :namespace) # rubocop: disable CodeReuse/ActiveRecord -- Avoid N+1 queries
          .each_batch do |add_on_purchases|
            add_on_purchases.ready_for_cleanup.each do |add_on_purchase|
              deleted_assigned_users = GitlabSubscriptions::UserAddOnAssignment # rubocop: disable Cop/DestroyAll -- https://gitlab.com/gitlab-org/gitlab/-/merge_requests/171331#note_2189629294
                .for_add_on_purchases(add_on_purchase)
                .destroy_all

              log_event(add_on_purchase, deleted_assigned_users.count) if deleted_assigned_users.count > 0
            end
          end
      end

      private

      def log_event(add_on_purchase, deleted_assigned_users_count)
        Gitlab::AppLogger.info(
          add_on: add_on_purchase.add_on.name,
          message: 'User add-on assignments for GitlabSubscriptions::AddOnPurchase were deleted via scheduled CronJob',
          namespace: add_on_purchase.namespace&.path,
          user_add_on_assignments_count: deleted_assigned_users_count
        )
      end
    end
  end
end
