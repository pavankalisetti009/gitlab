# frozen_string_literal: true

module Resolvers
  module WorkItems
    module Statuses
      class BulkStatusResolver < Resolvers::WorkItems::BaseResolver
        type Types::WorkItems::StatusType, null: true

        alias_method :status_widget, :object

        def resolve
          return unless work_item_status_feature_available?

          bulk_load_statuses
        end

        private

        def root_ancestor
          work_item&.resource_parent&.root_ancestor
        end

        def work_item
          @work_item ||= status_widget.work_item
        end

        def bulk_load_statuses
          BatchLoader::GraphQL.for(work_item.id).batch do |work_item_ids, loader|
            current_statuses = ::WorkItems::Statuses::CurrentStatus
              .for_work_items_with_statuses(work_item_ids).index_by(&:work_item_id)

            work_item_ids.each do |work_item_id|
              current_status = current_statuses[work_item_id]
              loader.call(work_item_id, current_status&.status)
            end
          end
        end
      end
    end
  end
end
