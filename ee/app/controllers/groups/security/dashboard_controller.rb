# frozen_string_literal: true
class Groups::Security::DashboardController < Groups::ApplicationController
  include GovernUsageGroupTracking

  layout 'group'

  feature_category :vulnerability_management
  urgency :low
  track_govern_activity 'security_dashboard', :show, conditions: :dashboard_available?
  track_internal_event :show, name: 'visit_upgraded_security_dashboard', category: name,
    conditions: -> { upgraded_dashboard_available? }
  track_internal_event :show, name: 'visit_security_dashboard', category: name,
    conditions: -> { dashboard_available? && !upgraded_dashboard_available? }
  before_action only: :show do
    push_frontend_feature_flag(:group_security_dashboard_new, group)
    push_frontend_feature_flag(:new_security_dashboard_total_risk_score, group)
    push_frontend_feature_flag(:group_vulnerability_risk_scores_by_project, group)
    push_frontend_ability(ability: :access_advanced_vulnerability_management, resource: group, user: current_user)
  end

  def show
    render :unavailable unless dashboard_available?
  end

  private

  def dashboard_available?
    can?(current_user, :read_group_security_dashboard, group)
  end

  def upgraded_dashboard_available?
    dashboard_available? && Feature.enabled?(:group_security_dashboard_new, group) &&
      can?(current_user, :access_advanced_vulnerability_management, group)
  end
end
