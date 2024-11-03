# frozen_string_literal: true

module Search
  module Zoekt
    class UpdateIndexUsedBytesWorker
      include Gitlab::EventStore::Subscriber
      include Search::Worker
      prepend ::Geo::SkipSecondary

      urgency :low
      idempotent!

      # https://gitlab.com/gitlab-org/gitlab/-/issues/499620
      def handle_event(event); end
    end
  end
end
