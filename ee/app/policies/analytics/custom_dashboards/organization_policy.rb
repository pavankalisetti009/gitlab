# frozen_string_literal: true

module Analytics
  module CustomDashboards
    module OrganizationPolicy
      extend ActiveSupport::Concern

      included do
        condition(:product_analytics_enabled) do
          License.feature_available?(:product_analytics)
        end

        condition(:custom_dashboards_feature_enabled) do
          # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Organization is not a supported actor type
          ::Feature.enabled?(:custom_dashboard_storage)
          # rubocop:enable Gitlab/FeatureFlagWithoutActor
        end

        rule do
          (admin | organization_user) & product_analytics_enabled & custom_dashboards_feature_enabled
        end.enable :read_custom_dashboard

        rule { (admin | organization_owner) & product_analytics_enabled & custom_dashboards_feature_enabled }.policy do
          enable :create_custom_dashboard
          enable :update_custom_dashboard
          enable :delete_custom_dashboard
        end
      end
    end
  end
end
