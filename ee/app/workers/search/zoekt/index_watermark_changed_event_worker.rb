# frozen_string_literal: true

module Search
  module Zoekt
    class IndexWatermarkChangedEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!

      # Deprecated worker
      def handle_event(_); end
    end
  end
end
