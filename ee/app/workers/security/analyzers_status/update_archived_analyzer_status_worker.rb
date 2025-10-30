# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class UpdateArchivedAnalyzerStatusWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      feature_category :security_asset_inventories
      sidekiq_retry_in { 2.minutes.seconds.to_i }
      deduplicate :until_executing, including_scheduled: true

      def perform(project_id)
        UpdateArchivedService.execute(Project.find_by_id(project_id))
      end
    end
  end
end
