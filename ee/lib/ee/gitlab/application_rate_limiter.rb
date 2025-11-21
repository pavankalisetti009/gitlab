# frozen_string_literal: true

module EE
  module Gitlab
    module ApplicationRateLimiter
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        override :rate_limits
        def rate_limits
          super.merge({
            ai_catalog_item_report: { threshold: 10, interval: 1.minute },
            unique_project_downloads_for_application: {
              threshold: -> { application_settings.max_number_of_repository_downloads },
              interval: -> { application_settings.max_number_of_repository_downloads_within_time_period }
            },
            # actual values will get sent by Abuse::GitAbuse::NamespaceThrottleService
            unique_project_downloads_for_namespace: {
              threshold: 0,
              interval: 0
            },
            credit_card_verification_check_for_reuse: { threshold: 10, interval: 1.hour },
            code_suggestions_api_endpoint: { threshold: 60, interval: 1.minute },
            code_suggestions_direct_access: { threshold: 50, interval: 1.minute },
            code_suggestions_connection_details: { threshold: 10, interval: 1.minute },
            code_suggestions_x_ray_scan: { threshold: 60, interval: 1.minute },
            code_suggestions_x_ray_dependencies: { threshold: 60, interval: 1.minute },
            duo_workflow_direct_access: { threshold: 50, interval: 1.minute },
            soft_phone_verification_transactions_limit: {
              threshold: application_settings.soft_phone_verification_transactions_daily_limit,
              interval: 1.day
            },
            hard_phone_verification_transactions_limit: {
              threshold: application_settings.hard_phone_verification_transactions_daily_limit,
              interval: 1.day
            },
            container_scanning_for_registry_scans: { threshold: 50, interval: 1.day },
            dependency_scanning_sbom_scan_api_throttling: { threshold: 50, interval: 1.hour },
            dependency_scanning_sbom_scan_api_upload: { threshold: 400, interval: 1.hour },
            dependency_scanning_sbom_scan_api_download: { threshold: 6000, interval: 1.hour },
            virtual_registries_endpoints_api_limit: { threshold: -> {
              application_settings.virtual_registries_endpoints_api_limit
            }, interval: 15.seconds },

            # Secret Detection Partner API rate limits
            # Scoped to a project
            # More details:
            # https://gitlab.com/gitlab-org/gitlab/-/issues/567304#partner-api-rate-limit-scoping
            partner_aws_api: {
              threshold: 400,
              interval: 1.second
            },
            partner_gcp_api: {
              threshold: 500,
              interval: 1.second
            },
            partner_postman_api: {
              threshold: 4,
              interval: 1.second
            }
          }).freeze
        end
      end
    end
  end
end
