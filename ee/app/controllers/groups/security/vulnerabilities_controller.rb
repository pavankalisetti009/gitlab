# frozen_string_literal: true

module Groups
  module Security
    class VulnerabilitiesController < Groups::ApplicationController
      include GovernUsageGroupTracking

      layout 'group'

      feature_category :vulnerability_management
      urgency :low
      track_govern_activity 'security_vulnerabilities', :index, conditions: :dashboard_available?
      track_internal_event :index, name: 'visit_vulnerability_report', category: name,
        conditions: -> { dashboard_available? }

      before_action do
        push_frontend_feature_flag(:vulnerability_report_owasp_2021, @group)
        push_frontend_feature_flag(:vulnerability_report_vr_badge, @group, type: :beta)
        push_frontend_feature_flag(:vulnerability_report_vr_filter, @group, type: :beta)
        push_frontend_feature_flag(:vulnerability_report_security_scores, @group, type: :beta)
        push_frontend_feature_flag(:enhanced_vulnerability_bulk_actions, @group, type: :wip)

        push_frontend_ability(ability: :resolve_vulnerability_with_ai, resource: @group, user: current_user)
      end

      def index
        render :unavailable unless dashboard_available?
      end

      private

      def dashboard_available?
        can?(current_user, :read_group_security_dashboard, group)
      end
    end
  end
end
