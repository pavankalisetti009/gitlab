# frozen_string_literal: true

module Sbom
  module Ingestion
    module Tasks
      class UpdateSecurityPolicyDismissals < Base
        def execute
          return unless Feature.enabled?(:security_policy_warn_mode_license_scanning, project)

          policy_dismissals = project.policy_dismissals.for_merge_requests(
            project.merge_requests.by_merged_or_merge_or_squash_commit_sha(@pipeline.sha).select(:id)
          )

          return unless policy_dismissals.present?

          @occurrence_maps.each do |occurrence_map|
            component_licenses = licenses_fetcher.fetch(occurrence_map.report_component)
            component_name = occurrence_map.name

            component_licenses.each do |license|
              next unless license.name && component_name

              policy_dismissals.each do |policy_dismissal|
                next unless policy_dismissal.license_names.include?(license.name) &&
                  policy_dismissal.components(license.name).include?(component_name)

                policy_dismissal.license_occurrence_uuids << occurrence_map.uuid
                policy_dismissal.save!
              end
            end
          end
        end

        private

        def licenses_fetcher
          Sbom::Ingestion::LicensesFetcher.new(project, occurrence_maps)
        end
        strong_memoize_attr :licenses_fetcher
      end
    end
  end
end
