# frozen_string_literal: true

module Projects
  module Security
    class ComplianceDashboardsController < Projects::ApplicationController
      before_action :ensure_feature_enabled!

      feature_category :compliance_management

      def show; end

      private

      def ensure_feature_enabled!
        render_404 unless Ability.allowed?(current_user, :read_compliance_dashboard, project)
      end
    end
  end
end
