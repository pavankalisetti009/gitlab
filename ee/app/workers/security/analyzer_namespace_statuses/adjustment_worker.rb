# frozen_string_literal: true

module Security
  module AnalyzerNamespaceStatuses
    class AdjustmentWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      feature_category :security_asset_inventories

      def perform(namespaces_ids)
        return unless namespaces_ids.present?

        AnalyzerNamespaceStatuses::AdjustmentService.execute(namespaces_ids)
      end
    end
  end
end
