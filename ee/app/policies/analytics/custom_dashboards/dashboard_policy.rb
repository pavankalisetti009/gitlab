# frozen_string_literal: true

module Analytics
  module CustomDashboards
    class DashboardPolicy < BasePolicy
      delegate { @subject.organization }

      condition(:namespace_scoped) do
        @subject.namespace_id.present?
      end

      condition(:is_dashboard_creator) do
        @subject.created_by_id == @user&.id
      end

      condition(:can_read_namespace) do
        @subject.namespace && Ability.allowed?(@user, :reporter_access, @subject.namespace)
      end

      condition(:can_develop_namespace) do
        @subject.namespace && Ability.allowed?(@user, :developer_access, @subject.namespace)
      end

      rule { namespace_scoped & can_read_namespace }.enable :read_custom_dashboard
      rule { namespace_scoped & ~can_read_namespace }.prevent :read_custom_dashboard

      rule { namespace_scoped & can_develop_namespace }.enable :create_custom_dashboard
      rule { namespace_scoped & ~can_develop_namespace }.prevent :create_custom_dashboard

      rule { can_read_namespace & (can_develop_namespace | is_dashboard_creator) }.policy do
        enable :update_custom_dashboard
        enable :delete_custom_dashboard
      end

      rule { namespace_scoped & ~(can_read_namespace & (can_develop_namespace | is_dashboard_creator)) }.policy do
        prevent :update_custom_dashboard
        prevent :delete_custom_dashboard
      end
    end
  end
end
