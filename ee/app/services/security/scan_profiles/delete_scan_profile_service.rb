# frozen_string_literal: true

module Security
  module ScanProfiles
    class DeleteScanProfileService
      CONNECTIONS_BATCH_SIZE = 500

      def self.execute(scan_profile_id)
        new(scan_profile_id: scan_profile_id).execute
      end

      def initialize(scan_profile_id:)
        @scan_profile = Security::ScanProfile.find_by_id(scan_profile_id)
      end

      def execute
        return unless scan_profile.present?

        delete_all_profile_connections
        scan_profile.destroy
      end

      private

      attr_reader :scan_profile

      def delete_all_profile_connections
        scan_profile_project_batches.each do |ids|
          delete_profile_connections(ids)
        end
      end

      def scan_profile_project_batches
        Enumerator.new do |yielder|
          last_id = 0
          loop do
            ids = Security::ScanProfileProject
              .for_scan_profile(scan_profile.id)
              .id_after(last_id)
              .ordered_by_id
              .scan_profile_project_ids(CONNECTIONS_BATCH_SIZE)
            break if ids.empty?

            yielder << ids
            last_id = ids.last
          end
        end
      end

      def delete_profile_connections(ids)
        Security::ScanProfileProject.id_in(ids).delete_all
      end
    end
  end
end
