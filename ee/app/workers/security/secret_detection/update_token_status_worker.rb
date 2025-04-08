# frozen_string_literal: true

# Worker for creating and updating token status records for findings from security scans.
#
# This worker processes secret detection findings from a pipeline and creates
# or updates FindingTokenStatus records that indicate whether detected tokens
# match known personal access tokens and their current status.
#
module Security
  module SecretDetection
    class UpdateTokenStatusWorker
      include ApplicationWorker

      feature_category :secret_detection
      data_consistency :sticky

      idempotent!

      concurrency_limit -> { 20 }

      DEFAULT_BATCH_SIZE = 100

      # Creates or updates FindingTokenStatus records for secret detection findings in a pipeline.
      #
      # @param [Integer] pipeline_id ID of the pipeline containing security scan results
      def perform(pipeline_id)
        @pipeline = Ci::Pipeline.find_by_id(pipeline_id)
        return unless @pipeline

        return unless Feature.enabled?(:validity_checks, @pipeline.project)

        Vulnerabilities::Finding
          .report_type('secret_detection')
          .by_latest_pipeline(pipeline_id)
          .each_batch(of: DEFAULT_BATCH_SIZE) do |batch_findings|
          process_findings_batch(batch_findings)
        end
      end

      private

      # Processes a batch of findings to create or update their FindingTokenStatus records.
      #
      # @param [ActiveRecord::Relation] findings A batch of Vulnerabilities::Finding records
      def process_findings_batch(findings)
        return if findings.empty?

        token_status_attr_by_sha = build_token_status_attributes_by_token_sha(findings)
        tokens = PersonalAccessToken.with_token_digests(token_status_attr_by_sha.keys)

        tokens.each do |token|
          token_status_attr_by_sha[token.token_digest].each do |finding_token_status_attr|
            finding_token_status_attr[:status] = token_status(token)
          end
        end

        attributes_to_upsert = token_status_attr_by_sha.values.flatten
        return if attributes_to_upsert.empty?

        begin
          Vulnerabilities::FindingTokenStatus.upsert_all(attributes_to_upsert,
            unique_by: :vulnerability_occurrence_id,
            update_only: [:status])
        rescue StandardError => e
          Gitlab::ErrorTracking.track_exception(
            e,
            pipeline_id: @pipeline.id,
            project_id: @pipeline.project_id,
            finding_count: attributes_to_upsert.size
          )

          Gitlab::AppLogger.error(
            message: "Failed to upsert finding token statuses",
            exception: e.class.name,
            exception_message: e.message,
            pipeline_id: @pipeline&.id,
            project_id: @pipeline.project_id,
            finding_count: attributes_to_upsert.size
          )

          # Re-raise the exception to trigger Sidekiq retry mechanism
          raise
        end
      end

      # Determines the appropriate status value for a FindingTokenStatus based on a personal access token.
      #
      # @param [PersonalAccessToken, nil] token The token to check, or nil if not found
      # @return [String] 'active', 'inactive', or 'unknown'
      def token_status(token)
        return 'unknown' unless token

        token.active? ? 'active' : 'inactive'
      end

      # Builds attributes for FindingTokenStatus records grouped by token SHA.
      #
      # @param [ActiveRecord::Relation] latest_secret_findings Secret detection findings
      # @return [Hash] A hash mapping token SHAs to arrays of FindingTokenStatus attributes
      def build_token_status_attributes_by_token_sha(findings)
        now = Time.current
        findings.each_with_object({}) do |finding, attr_by_sha|
          token_value = finding.metadata['raw_source_code_extract']
          token_sha = Gitlab::CryptoHelper.sha256(token_value)

          attr_by_sha[token_sha] ||= []
          attr_by_sha[token_sha] << build_finding_token_status_attributes(finding, now)
        end
      end

      # Builds attributes for a single FindingTokenStatus record.
      #
      # @param [Vulnerabilities::Finding] finding The finding containing the token
      # @param [Time] time The timestamp to use for created_at and updated_at
      # @param [String] status Initial status to set (default: 'unknown')
      # @return [Hash] Attributes for creating a FindingTokenStatus record
      def build_finding_token_status_attributes(finding, time, status = 'unknown')
        {
          vulnerability_occurrence_id: finding.id,
          project_id: finding.project_id,
          status: status,
          created_at: time,
          updated_at: time
        }
      end
    end
  end
end
