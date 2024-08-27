# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    class BackfillProjectIdToSecurityScans < BatchedMigrationJob
      feature_category :vulnerability_management
      operation_name :backfill_project_id_to_security_scans

      class Scan < ::Gitlab::Database::SecApplicationRecord
        self.table_name = 'security_scans'
      end

      class Build < ::Ci::ApplicationRecord
        self.table_name = 'p_ci_builds'
      end

      def perform
        each_sub_batch do |sub_batch|
          scans = sub_batch
          builds = Build.id_in(scans.map(&:build_id))

          missing_build_ids = []

          scans.each do |scan|
            build = builds.find { |build| build.id == scan.build_id }

            if build.blank?
              missing_build_ids.push(scan.id)
              next
            end

            scan.project_id = build.project_id

            # Can this be done in bulk?
            scan.save!
          end

          Scan.id_in(missing_build_ids).delete_all if missing_build_ids.present?
        end
      end
    end
  end
end
