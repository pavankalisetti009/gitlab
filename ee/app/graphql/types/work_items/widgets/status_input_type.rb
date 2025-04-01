# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      class StatusInputType < BaseInputObject
        graphql_name 'WorkItemWidgetStatusInput'

        argument :status, Types::GlobalIDType[::WorkItems::Statuses::Status],
          required: false,
          description: 'Status of the work item.',
          prepare: ->(global_id, _) {
            return if global_id.nil?

            # ::WorkItems::Statuses::SystemDefined::Status is a FixedItemsModel and not AR
            # so we need to manually resolve the global ID to the model instance.
            # In the future we'll also support custom statuses through this interface
            status = global_id.model_class.find(global_id.model_id.to_i)
            raise GraphQL::ExecutionError, "System-defined status doesn't exist." if status.nil?

            status
          }
      end
    end
  end
end
