# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class UpdateService
        include EventsTracking

        def initialize(item_consumer, current_user, _params)
          @current_user = current_user
          @item_consumer = item_consumer
          # Currently this service is a no-op.
          # TODO Use params#slice to select specific params as we support them.
          @params = {}
        end

        def execute
          return error_no_permissions unless allowed?

          if item_consumer.update(params)
            track_item_consumer_event(item_consumer, 'update_ai_catalog_item_consumer')
            ServiceResponse.success(payload: { item_consumer: item_consumer })
          else
            error_updating
          end
        end

        private

        attr_reader :current_user, :item_consumer, :params

        def allowed?
          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, item_consumer)
        end

        def error_no_permissions
          error('You have insufficient permission to update this item consumer')
        end

        def error(message)
          ServiceResponse.error(payload: { item_consumer: item_consumer }, message: Array(message))
        end

        def error_updating
          error(item_consumer.errors.full_messages.presence || 'Failed to update item consumer')
        end
      end
    end
  end
end
