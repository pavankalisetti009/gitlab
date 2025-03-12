# frozen_string_literal: true

module Resolvers
  module WorkItems
    module Widgets
      class StatusResolver < BaseResolver
        type ::Types::WorkItems::Widgets::StatusType.connection_type, null: true

        def resolve
          return [] unless work_item_status_feature_available?

          # As part of iteration 1, we only support system defined statuses
          # Custom lifecycle based on namespace will be supported in iteration 2
          lifecycle_for(object.work_item_type)&.statuses || []
        end

        private

        def work_item_status_feature_available?
          root_ancestor&.try(:work_item_status_feature_available?)
        end

        def root_ancestor
          context[:resource_parent]&.root_ancestor
        end

        def lifecycle_for(work_item_type)
          base_type = work_item_type.base_type.to_sym
          ::WorkItems::Statuses::SystemDefined::Lifecycle.of_work_item_base_type(base_type)
        end
      end
    end
  end
end
