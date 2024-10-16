# frozen_string_literal: true

class ElasticIndexingControlWorker
  include ApplicationWorker
  include Search::Worker
  prepend ::Geo::SkipSecondary
  data_consistency :always

  sidekiq_options retry: 3

  idempotent!

  def perform
    if Elastic::IndexingControl.non_cached_pause_indexing?
      raise 'elasticsearch_pause_indexing is enabled, worker can not proceed'
    end

    Elastic::IndexingControl.resume_processing!
  end
end
