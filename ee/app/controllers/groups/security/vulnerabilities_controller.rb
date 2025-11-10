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
        push_frontend_feature_flag(:validity_check_es_filter, @group, type: :gitlab_com_derisk)
        push_frontend_feature_flag(:hide_vulnerability_severity_override, @group.root_ancestor, type: :ops)
        push_frontend_feature_flag(:existing_jira_issue_attachment_from_vulnerability_bulk_action, @project, type: :wip)
        push_frontend_ability(ability: :resolve_vulnerability_with_ai, resource: @group, user: current_user)
        push_frontend_feature_flag(:security_policy_approval_warn_mode, @group, type: :wip)
        push_frontend_feature_flag(:policy_violations_es_filter, @group, type: :beta)
        push_frontend_feature_flag(:ai_experiment_sast_fp_detection, @group, type: :wip)
        push_frontend_ability(ability: :access_advanced_vulnerability_management, resource: @group, user: current_user)
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
