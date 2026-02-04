# frozen_string_literal: true

module Projects
  module Settings
    class WorkItemsController < Projects::ApplicationController
      layout 'project_settings'
      feature_category :team_planning

      before_action :authorize_work_item_settings!

      private

      def authorize_work_item_settings!
        access_denied! unless ::Feature.enabled?(:work_item_configurable_types, @project)
      end
    end
  end
end
