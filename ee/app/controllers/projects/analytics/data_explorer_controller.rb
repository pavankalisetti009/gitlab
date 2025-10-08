# frozen_string_literal: true

module Projects
  module Analytics
    class DataExplorerController < Projects::ApplicationController
      feature_category :team_planning

      before_action :validate_feature_flag

      def show; end

      private

      def validate_feature_flag
        not_found unless ::Feature.enabled?(:analyze_data_explorer, project.group)
      end
    end
  end
end
