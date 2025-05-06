# frozen_string_literal: true

module Resolvers
  module WorkItems
    module Widgets
      class AllowedStatusesResolver < Resolvers::WorkItems::BaseResolver
        type [::Types::WorkItems::Widgets::StatusType], null: true

        alias_method :widget_definition, :object

        def resolve
          return [] unless work_item_status_feature_available?

          custom_statuses.presence || system_defined_statuses
        end

        private

        def root_ancestor
          context[:resource_parent]&.root_ancestor
        end
        strong_memoize_attr :root_ancestor

        def work_item_type
          widget_definition.work_item_type
        end
        strong_memoize_attr :work_item_type

        def custom_statuses
          return [] unless custom_status_enabled?

          custom_lifecycle&.ordered_statuses || []
        end

        def system_defined_statuses
          system_defined_lifecycle&.statuses || []
        end

        def custom_lifecycle
          return unless root_ancestor

          work_item_type.custom_lifecycle_for(root_ancestor.id)
        end

        def system_defined_lifecycle
          base_type = work_item_type.base_type.to_sym
          ::WorkItems::Statuses::SystemDefined::Lifecycle.of_work_item_base_type(base_type)
        end

        def custom_status_enabled?
          return false unless root_ancestor

          work_item_type.custom_status_enabled_for?(root_ancestor.id)
        end
      end
    end
  end
end
