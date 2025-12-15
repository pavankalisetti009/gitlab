# frozen_string_literal: true

module EE
  module Organizations
    module OrganizationPolicy
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        include RemoteDevelopment::OrganizationPolicy

        condition(:dependency_scanning_enabled) do
          License.feature_available?(:dependency_scanning)
        end

        condition(:license_scanning_enabled) do
          License.feature_available?(:license_scanning)
        end

        condition(:product_analytics_enabled) do
          License.feature_available?(:product_analytics)
        end

        condition(:custom_dashboards_feature_enabled) do
          # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Organization is not a supported actor type
          ::Feature.enabled?(:custom_dashboard_storage)
          # rubocop:enable Gitlab/FeatureFlagWithoutActor
        end

        rule { (admin | organization_user) & dependency_scanning_enabled }.enable :read_dependency
        rule { (admin | organization_user) & license_scanning_enabled }.enable :read_licenses

        rule do
          (admin | organization_user) & product_analytics_enabled & custom_dashboards_feature_enabled
        end.enable :read_custom_dashboard

        rule do
          (admin | organization_owner) & product_analytics_enabled & custom_dashboards_feature_enabled
        end.enable :create_custom_dashboard
      end
    end
  end
end
