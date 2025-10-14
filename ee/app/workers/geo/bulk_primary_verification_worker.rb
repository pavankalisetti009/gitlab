# frozen_string_literal: true

module Geo
  class BulkPrimaryVerificationWorker
    include ApplicationWorker
    include Gitlab::Geo::LogHelpers

    idempotent!
    data_consistency :sticky
    deduplicate :until_executed, ttl: 1.hour

    feature_category :geo_replication

    # The parameter `model_name` must be the string representation of a Geo-enabled model
    # as defined in the helper class Gitlab::Geo::ModelMapper.
    def perform(model_name)
      result = Geo::BulkPrimaryVerificationService.new(model_name).execute

      log_extra_metadata_on_done(:result, { status: result.payload[:status] })
    end
  end
end
