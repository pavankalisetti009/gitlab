# frozen_string_literal: true

module Groups
  module Analytics
    class DataExplorerController < Groups::Analytics::ApplicationController
      layout 'group'
      feature_category :value_stream_management

      before_action :validate_feature_flag

      def show; end

      private

      def validate_feature_flag
        not_found unless ::Feature.enabled?(:analyze_data_explorer, group)
      end
    end
  end
end
