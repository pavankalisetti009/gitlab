# frozen_string_literal: true

module Vulnerabilities
  module Removal
    # This class is responsible for removing the vulnerability records
    # associated with the given project.
    #
    # We are not deleting the `scanner` records because they are associated
    # with the `security_findings` records and deleting them scan cause
    # cascading delete on millions of `security_findings` records.
    class RemoveFromProjectService
      class BatchRemoval
        TASKS_SCOPED_TO_FINDINGS = [
          Tasks::DeleteFindingEvidences,
          Tasks::DeleteFindingFlags,
          Tasks::DeleteFindingIdentifiers,
          Tasks::DeleteFindingLinks,
          Tasks::DeleteFindingRemediations,
          Tasks::DeleteFindingSignatures
        ].freeze

        TASKS_SCOPED_TO_VULNERABILITIES = [
          Tasks::DeleteVulnerabilityExternalIssueLinks,
          Tasks::DeleteVulnerabilityIssueLinks,
          Tasks::DeleteVulnerabilityMergeRequestLinks,
          Tasks::DeleteVulnerabilityReads,
          Tasks::DeleteVulnerabilityStateTransitions,
          Tasks::DeleteVulnerabilityUserMentions
        ].freeze

        def initialize(project, batch)
          @project = project
          @batch = batch
        end

        def execute
          Vulnerability.transaction do
            delete_resources_by_findings
            delete_resources_by_vulnerabilities
            delete_vulnerabilities
            delete_findings
          end

          update_project_vulnerabilities_count
        end

        private

        attr_reader :project, :batch

        def delete_resources_by_findings
          TASKS_SCOPED_TO_FINDINGS.each { |task| task.new(finding_ids).execute }
        end

        def delete_resources_by_vulnerabilities
          TASKS_SCOPED_TO_VULNERABILITIES.each { |task| task.new(vulnerability_ids).execute }
        end

        def delete_vulnerabilities
          Vulnerability.id_in(vulnerability_ids).delete_all
        end

        def delete_findings
          Vulnerabilities::Finding.id_in(finding_ids).delete_all
        end

        def update_project_vulnerabilities_count
          project.statistics.decrease_vulnerability_counter!(batch_size)
        end

        def batch_size
          vulnerability_ids.length
        end

        def vulnerability_ids
          @vulnerability_ids ||= batch_attributes.map(&:first)
        end

        def finding_ids
          @finding_ids ||= batch_attributes.map(&:second)
        end

        def batch_attributes
          @batch_attributes ||= batch.pluck(:id, :finding_id) # rubocop:disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- This is a very specific usage
        end
      end

      BATCH_SIZE = 100

      def initialize(project)
        @project = project
      end

      def execute
        ::Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification.temporary_ignore_tables_in_transaction(
          %i[
            vulnerability_feedback
            vulnerability_finding_links
            vulnerability_findings_remediations
            vulnerability_occurrences
            vulnerability_occurrence_pipelines
            vulnerability_historical_statistics
            vulnerability_reads
            vulnerability_merge_request_links
          ],
          url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/474140'
        ) do
          vulnerabilities.each_batch(of: BATCH_SIZE) do |batch|
            Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification.temporary_ignore_tables_in_transaction(
              %w[
                vulnerabilities
                vulnerability_historical_statistics
                vulnerability_identifiers
                vulnerability_occurrences
                vulnerability_reads
                vulnerability_scanners
                vulnerability_merge_request_links
              ], url: 'https://gitlab.com/groups/gitlab-org/-/epics/14116#identified-cross-joins'
            ) do
              BatchRemoval.new(project, batch).execute
            end
          end

          update_vulnerability_statistics
          delete_feedback_records
          delete_historical_statistics
        end
      end

      private

      attr_reader :project

      def vulnerabilities
        Vulnerability.with_project(project)
      end

      def update_vulnerability_statistics
        Vulnerabilities::Statistics::AdjustmentWorker.perform_async(project.id)
      end

      # Do we really need to delete these records? The feedback model has already been
      # deprecated and the model will be removed soon.
      def delete_feedback_records
        loop { break if project.vulnerability_feedback.limit(BATCH_SIZE).delete_all == 0 }
      end

      def delete_historical_statistics
        loop { break if project.vulnerability_historical_statistics.limit(BATCH_SIZE).delete_all == 0 }
      end
    end
  end
end
