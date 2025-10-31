# frozen_string_literal: true

module Geo
  # Service that marks primary model state as verification_pending in batches
  # to be resynchronized by Geo periodic workers later
  # This service can accept as argument `params` a hash containing:
  # - :identifiers, Array: an array of the IDs for the verification state records to update (not model IDs!)
  # - :checksum_state, String: the verification state of the records to be rechecksummed
  class BulkPrimaryVerificationService < BaseBatchBulkUpdateService
    extend Gitlab::Utils::Override

    private

    override :model_to_update
    def model_to_update
      log_error("Model not found") && return unless class_name

      model_class = class_name.safe_constantize
      log_error("Model #{class_name} not found") && return unless model_class

      model_class.verification_state_table_class
    end

    override :attributes_to_update
    def attributes_to_update
      { verification_state: 0 }
    end

    override :update_scope
    def update_scope
      scope = model_to_update.verification_state_not_pending
      scope = scope.primary_key_in(params[:identifiers]) if params[:identifiers].present?
      scope = scope.with_verification_state(params[:checksum_state]) if params[:checksum_state].present?

      scope
    end

    override :worker
    def worker
      Geo::BulkPrimaryVerificationWorker
    end
  end
end
