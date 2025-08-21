# frozen_string_literal: true

module Groups
  module Settings
    class WorkItemsController < Groups::ApplicationController
      layout 'group_settings'

      before_action :ensure_root_group
      before_action :check_feature_availability_and_authorize

      feature_category :team_planning
      urgency :low

      before_action do
        push_frontend_feature_flag(:work_item_status_mvc2, group)
      end

      def show; end

      private

      def ensure_root_group
        render_404 unless group.root?
      end

      def check_feature_availability_and_authorize
        render_404 unless can_access_work_item_settings?
      end

      def can_access_work_item_settings?
        can_admin_custom_fields? || can_admin_work_item_statuses?
      end

      def can_admin_custom_fields?
        group.licensed_feature_available?(:custom_fields) && can?(current_user, :admin_custom_field, group)
      end

      def can_admin_work_item_statuses?
        group.licensed_feature_available?(:work_item_status) && can?(current_user, :admin_work_item_lifecycle, group)
      end
    end
  end
end
