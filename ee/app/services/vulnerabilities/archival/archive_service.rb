# frozen_string_literal: true

module Vulnerabilities
  module Archival
    class ArchiveService
      BATCH_SIZE = 100

      def self.execute(...)
        new(...).execute
      end

      def initialize(project, archive_before_date)
        @project = project
        @archive_before_date = archive_before_date
        @date = Time.zone.today
      end

      def execute
        loop do
          batch = vulnerabilities.with_mrs_and_issues.with_triaging_users.limit(BATCH_SIZE)

          break unless batch.exists?

          process_batch(batch)
        end
      end

      private

      attr_reader :project, :archive_before_date, :date

      def vulnerabilities
        project.vulnerabilities.last_updated_before(archive_before_date)
      end

      def process_batch(batch)
        active_vulnerabilities, stale_vulnerabilities = partition_by_mr_and_issue_activity(batch)

        touch(active_vulnerabilities)
        archive(stale_vulnerabilities)
      end

      def partition_by_mr_and_issue_activity(batch)
        batch.partition { |vulnerability| vulnerability.has_mr_or_issue_updated_after?(date) }
      end

      # We are updating the vulnerabilities with active MRs or issues here to
      # prevent receiving them again from database in the next iteration.
      def touch(vulnerabilities)
        Vulnerability.id_in(vulnerabilities).update_all(updated_at: Time.zone.now)
      end

      def archive(vulnerabilities)
        Vulnerabilities::Archival::ArchiveBatchService.execute(vulnerability_archive, vulnerabilities)
      end

      # rubocop:disable Performance/ActiveRecordSubtransactionMethods -- This method doesn't run in a transaction so it doesn't create a save point.
      def vulnerability_archive
        @vulnerability_archive ||= project.vulnerability_archives.safe_find_or_create_by(date: date.beginning_of_month)
      end
      # rubocop:enable Performance/ActiveRecordSubtransactionMethods
    end
  end
end
