# frozen_string_literal: true

module Epics
  class UpdateDatesService < ::BaseService
    BATCH_SIZE = 100

    STRATEGIES = [
      Epics::Strategies::StartDateInheritedStrategy,
      Epics::Strategies::DueDateInheritedStrategy
    ].freeze

    def initialize(epics)
      @epics = epics
      @epics = Epic.id_in(@epics) unless @epics.is_a?(ActiveRecord::Relation)
    end

    def execute
      # We need to either calculate the rolledup dates from the legacy epic side and sync to the work item,
      # or calculate it on the work item side and sync to the legacy epic.
      # If we'd run the jobs on both sides, we could end up with a race condition.
      if @epics.first&.group&.work_items_rolledup_dates_feature_flag_enabled?
        ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService
                  .new(WorkItem.id_in(@epics.select(:issue_id)))
                  .execute
      else
        each_batch do |relation, parent_ids|
          STRATEGIES.each do |strategy|
            strategy.new(relation).execute
          end

          if parent_ids.any?
            Epics::UpdateEpicsDatesWorker.perform_async(parent_ids)
          end
        end
      end
    end

    private

    # rubocop: disable CodeReuse/ActiveRecord
    def each_batch
      @epics.in_batches(of: BATCH_SIZE) do |relation| # rubocop: disable Cop/InBatches
        parent_ids = relation.has_parent.distinct.pluck(:parent_id)

        yield(relation, parent_ids)
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end
