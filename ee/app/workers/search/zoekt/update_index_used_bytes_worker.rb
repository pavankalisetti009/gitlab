# frozen_string_literal: true

module Search
  module Zoekt
    class UpdateIndexUsedBytesWorker
      include ApplicationWorker
      include Search::Worker
      prepend ::Geo::SkipSecondary

      data_consistency :delayed
      urgency :low
      idempotent!

      # https://gitlab.com/gitlab-org/gitlab/-/issues/499620
      def perform(*); end
    end
  end
end
