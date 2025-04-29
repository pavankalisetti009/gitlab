# frozen_string_literal: true

module Security
  class PipelineAnalyzersStatusUpdateWorker
    include ApplicationWorker

    data_consistency :sticky
    idempotent!
    feature_category :security_asset_inventories

    def perform(pipeline_id)
      pipeline = Ci::Pipeline.find_by_id(pipeline_id)
      return unless pipeline.present?

      return unless pipeline.project.licensed_feature_available?(:security_dashboard)

      AnalyzersStatus::UpdateService.new(pipeline).execute
    end
  end
end
