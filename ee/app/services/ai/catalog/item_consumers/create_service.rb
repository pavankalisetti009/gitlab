# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class CreateService < ::BaseContainerService
        include InternalEventsTracking

        def execute
          return error_no_permissions unless allowed?
          return error('Catalog item is not a flow') unless item.flow?

          params.merge!(project: project, group: group)
          item_consumer = ::Ai::Catalog::ItemConsumer.new(params)

          if item_consumer.save
            track_item_consumer_event(item_consumer, 'create_ai_catalog_item_consumer')
            ServiceResponse.success(payload: { item_consumer: item_consumer })
          else
            error_creating(item_consumer)
          end
        end

        private

        def item
          params[:item]
        end

        def error_creating(item_consumer)
          error(item_consumer.errors.full_messages.presence || 'Failed to create item consumer')
        end

        def allowed?
          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, container) &&
            Ability.allowed?(current_user, :read_ai_catalog_item, item)
        end

        def error(message)
          ServiceResponse.error(message: Array(message))
        end

        def error_no_permissions
          error('Item does not exist, or you have insufficient permissions')
        end
      end
    end
  end
end
