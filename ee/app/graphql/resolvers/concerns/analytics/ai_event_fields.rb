# frozen_string_literal: true

module Analytics
  module AiEventFields
    # Ai usage events exposed on API.
    # Uses AiUsageEventTypeEnum as single source of truth.
    def exposed_events(feature = nil)
      events = ::Gitlab::Tracking::AiTracking.registered_events(feature).keys
      allowed_events = ::Types::Analytics::AiUsage::AiUsageEventTypeEnum.values.each_value.map(&:value)
      events & allowed_events
    end
  end
end
