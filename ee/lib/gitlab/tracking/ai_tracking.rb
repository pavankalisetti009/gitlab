# frozen_string_literal: true

module Gitlab
  module Tracking
    module AiTracking
      class << self
        def track_event(event_name, **context_hash)
          OldApproach.track_event(event_name, **context_hash)
        end

        def track_user_activity(user)
          ::Ai::UserMetrics.refresh_last_activity_on(user)
        end
      end
    end
  end
end
