# frozen_string_literal: true

module Groups
  module Settings
    class WorkItemsController < Groups::ApplicationController
      layout 'group_settings'

      before_action :check_feature_availability

      feature_category :team_planning
      urgency :low

      def show; end

      private

      def check_feature_availability
        render_404 unless group.licensed_feature_available?(:custom_fields) &&
          Feature.enabled?('custom_fields_feature', group)
      end
    end
  end
end
