# frozen_string_literal: true

module Projects
  module Security
    class DashboardController < Projects::ApplicationController
      include SecurityAndCompliancePermissions
      include SecurityDashboardsPermissions
      include GovernUsageProjectTracking

      before_action do
        push_frontend_feature_flag(:vulnerabilities_pdf_export, project)
        push_frontend_feature_flag(:project_security_dashboard_new, project)
        push_frontend_feature_flag(:new_security_dashboard_vulnerabilities_per_severity, project)
        push_frontend_ability(ability: :access_advanced_vulnerability_management, resource: project, user: current_user)
      end

      alias_method :vulnerable, :project

      feature_category :vulnerability_management
      urgency :low
      track_govern_activity 'security_dashboard', :index
      track_internal_event :index, name: 'visit_security_dashboard', category: name
    end
  end
end
