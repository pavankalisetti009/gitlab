# frozen_string_literal: true

module WorkItems
  module Callbacks
    class RolledupDates < Base
      def after_save
        return unless params.present? && can_set_rolledup_dates?

        (work_item.dates_source || work_item.build_dates_source).then do |dates_source|
          dates_source.update(AttributesBuilder.build(work_item, params))
        end
      end

      def after_update_commit
        ::WorkItems::Widgets::RolledupDatesService::HierarchyUpdateService
          .new(work_item)
          .execute
      end

      private

      def can_set_rolledup_dates?
        return true if params.fetch(:synced_work_item, false)

        work_item.resource_parent.work_items_rolledup_dates_feature_flag_enabled? &&
          has_permission?(:set_work_item_metadata)
      end
    end
  end
end
