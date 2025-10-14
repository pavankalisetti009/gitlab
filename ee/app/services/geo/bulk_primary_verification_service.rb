# frozen_string_literal: true

module Geo
  # Service that marks primary model state as verification_pending in batches
  # to be resynchronized by Geo periodic workers later
  class BulkPrimaryVerificationService < BaseBatchBulkUpdateService
    extend Gitlab::Utils::Override

    private

    override :model_to_update
    def model_to_update
      model_class = Gitlab::Geo::ModelMapper.find_from_name(worker_params)
      log_error("Model #{worker_params} not found") && return unless model_class

      model_class.verification_state_table_class
    end

    override :attributes_to_update
    def attributes_to_update
      { verification_state: 0 }
    end

    override :update_scope
    def update_scope
      model_to_update.verification_state_not_pending
    end

    override :worker
    def worker
      Geo::BulkPrimaryVerificationWorker
    end
  end
end
