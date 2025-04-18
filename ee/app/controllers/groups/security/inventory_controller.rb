# frozen_string_literal: true

module Groups
  module Security
    class InventoryController < Groups::ApplicationController
      layout 'group'

      before_action :ensure_feature_available!

      before_action do
        push_frontend_feature_flag(:security_inventory_dashboard, @group.root_ancestor)
      end

      feature_category :security_asset_inventories

      include ProductAnalyticsTracking

      track_internal_event :show, name: 'view_group_security_inventory'

      def show; end

      private

      def ensure_feature_available!
        render_404 unless License.feature_available?(:security_inventory) &&
          ::Feature.enabled?(:security_inventory_dashboard, group.root_ancestor, type: :wip)
      end

      def tracking_namespace_source
        group
      end

      def tracking_project_source; end
    end
  end
end
