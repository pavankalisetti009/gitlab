# frozen_string_literal: true

module Analytics
  class DuoChatEventsBackfillWorker
    include ApplicationWorker

    data_consistency :sticky
    feature_category :value_stream_management
    urgency :low
    idempotent!

    def perform(_event_type, _data)
      # no-op. removed in https://gitlab.com/gitlab-org/gitlab/-/issues/553215
    end
  end
end
