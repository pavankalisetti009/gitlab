# frozen_string_literal: true

module Groups
  module Security
    class InventoryController < Groups::ApplicationController
      layout 'group'

      before_action :ensure_feature_available!

      before_action do
        push_frontend_feature_flag(:security_inventory_dashboard, @group)
      end

      feature_category :security_asset_inventories

      def show; end

      private

      def ensure_feature_available!
        render_404 unless License.feature_available?(:security_inventory) &&
          ::Feature.enabled?(:security_inventory_dashboard, group, type: :wip)
      end
    end
  end
end
