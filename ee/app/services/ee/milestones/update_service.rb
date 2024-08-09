# frozen_string_literal: true

module EE
  module Milestones
    module UpdateService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute(milestone)
        super

        # When the feature flag is enabled, we already handle this on the WorkItem side and sync it to the epic.
        if saved_change_to_dates?(milestone) &&
            !milestone.resource_parent.work_items_rolledup_dates_feature_flag_enabled?
          Epics::UpdateDatesService.new(::Epic.in_milestone(milestone.id)).execute
        end

        milestone
      end

      private

      def saved_change_to_dates?(milestone)
        milestone.saved_change_to_start_date? || milestone.saved_change_to_due_date?
      end
    end
  end
end
