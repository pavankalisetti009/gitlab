# frozen_string_literal: true

module Analytics
  module AiEventFields
    # Ai usage events exposed on API.
    # Uses AiUsageEventTypeEnum as single source of truth.
    COUNT_FIELD_SUFFIX = '_event_count'

    def exposed_events(feature = nil)
      ::Gitlab::Tracking::AiTracking.registered_events(feature).keys
    end

    def count_field_name(event_name)
      (event_name + ::Analytics::AiEventFields::COUNT_FIELD_SUFFIX).to_sym
    end
  end
end
