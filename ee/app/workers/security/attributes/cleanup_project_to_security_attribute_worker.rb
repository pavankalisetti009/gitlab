# frozen_string_literal: true

module Security
  module Attributes
    class CleanupProjectToSecurityAttributeWorker
      include ApplicationWorker

      version 1
      data_consistency :sticky
      deduplicate :until_executed, including_scheduled: true
      feature_category :security_policy_management
      idempotent!
      urgency :low

      defer_on_database_health_signal :gitlab_main, [:project_to_security_attributes]

      def perform(attribute_ids = nil)
        return unless attribute_ids

        result = ::Security::Attributes::ProjectToSecurityAttributeDestroyService.new(
          attribute_ids: attribute_ids
        ).execute

        unless result.success?
          Gitlab::ErrorTracking.track_exception(
            StandardError.new(result.message),
            attribute_ids: attribute_ids,
            worker: self.class.name
          )
        end

        result
      end
    end
  end
end
