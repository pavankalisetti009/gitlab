# frozen_string_literal: true

module Search
  module Zoekt
    class NamespaceIndexerWorker
      include ApplicationWorker
      include Search::Worker
      prepend ::Geo::SkipSecondary

      # Must be always otherwise we risk race condition where it does not think that indexing is enabled yet for the
      # namespace.
      data_consistency :always
      idempotent!
      pause_control :zoekt

      def perform(namespace_id, operation, node_id = nil); end
    end
  end
end
