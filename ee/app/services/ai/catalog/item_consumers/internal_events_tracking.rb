# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      module InternalEventsTracking
        include Gitlab::InternalEventsTracking

        def track_item_consumer_event(item_consumer, event_name, custom_attrs = {})
          track_internal_event(
            event_name,
            **{
              user: current_user,
              project: item_consumer.project,
              namespace: item_consumer.group,
              additional_properties: {
                label: item_consumer.enabled.to_s,
                property: item_consumer.locked.to_s
              }
            }.merge(custom_attrs).compact
          )
        end
      end
    end
  end
end
