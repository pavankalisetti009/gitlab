# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class DestroyService
        include EventsTracking

        def initialize(item_consumer, current_user)
          @current_user = current_user
          @item_consumer = item_consumer
        end

        def execute
          return error_no_permissions unless allowed?

          if item_consumer.destroy
            track_item_consumer_event(item_consumer, 'delete_ai_catalog_item_consumer', additional_properties: nil)
            send_audit_events(item_consumer, audit_event_name)
            ServiceResponse.success(payload: { item_consumer: item_consumer })
          else
            error(item_consumer.errors.full_messages)
          end
        end

        private

        attr_reader :current_user, :item_consumer

        def audit_event_name
          "disable_ai_catalog_#{item_consumer.item.item_type}"
        end

        def allowed?
          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, item_consumer)
        end

        def error_no_permissions
          error('You have insufficient permissions to delete this item consumer')
        end

        def error(message)
          ServiceResponse.error(message: Array(message))
        end
      end
    end
  end
end
