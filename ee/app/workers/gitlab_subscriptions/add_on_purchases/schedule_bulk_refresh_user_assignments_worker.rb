# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    class ScheduleBulkRefreshUserAssignmentsWorker
      include ApplicationWorker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext
      include ::GitlabSubscriptions::CodeSuggestionsHelper

      feature_category :seat_cost_management
      data_consistency :sticky
      urgency :low

      idempotent!

      def perform
        return unless feature_flag_enabled?

        GitlabSubscriptions::AddOnPurchases::BulkRefreshUserAssignmentsWorker.perform_with_capacity
      end

      private

      def feature_flag_enabled?
        return true unless gitlab_com_subscription?

        Feature.enabled?(:bulk_add_on_assignment_refresh_worker)
      end
    end
  end
end
