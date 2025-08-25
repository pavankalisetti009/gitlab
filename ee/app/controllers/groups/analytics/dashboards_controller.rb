# frozen_string_literal: true

module Groups
  module Analytics
    class DashboardsController < Groups::Analytics::ApplicationController
      include ProductAnalyticsTracking

      before_action { authorize_view_by_action!(:read_group_analytics_dashboards) }
      before_action do
        push_frontend_feature_flag(:duo_rca_usage_rate, @group)
        push_frontend_feature_flag(:dora_metrics_dashboard, @group)

        [:read_dora4_analytics, :read_cycle_analytics, :read_security_resource].each do |ability|
          push_frontend_ability(ability: ability, resource: @group, user: current_user)
        end

        [:dora4_analytics, :security_dashboard].each do |license|
          push_licensed_feature(license, @group)
        end
      end

      layout 'group'
    end
  end
end
