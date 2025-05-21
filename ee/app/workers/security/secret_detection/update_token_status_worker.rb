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

      SECRET_TYPE_MAPPING = {
        'gitlab_personal_access_token' => 'gitlab_personal_access_token',
        'gitlab_personal_access_token_routable' => 'gitlab_personal_access_token',
        'gitlab_deploy_token' => 'gitlab_deploy_token'
      }.freeze

      # Creates or updates FindingTokenStatus records for secret detection findings in a pipeline.
      #
      # @param [Integer] pipeline_id ID of the pipeline containing security scan results
      def perform(pipeline_id)
        @pipeline = Ci::Pipeline.find_by_id(pipeline_id)
        return unless @pipeline

        return unless Feature.enabled?(:validity_checks, @pipeline.project)

        @token_lookup_service = Security::SecretDetection::TokenLookupService.new

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

        tokens_by_raw_token = get_tokens_by_raw_token_value(findings)

        token_status_attr_by_raw_token = build_token_status_attributes_by_raw_token(findings)

        # Set token status on token status attributes
        tokens_by_raw_token.each do |raw_token, token|
          token_status_attr_by_raw_token[raw_token].each do |finding_token_status_attr|
            finding_token_status_attr[:status] = token_status(token)
          end
        end

        attributes_to_upsert = token_status_attr_by_raw_token.values.flatten
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

      # Retrieves token objects by their raw token values from findings
      #
      # @param findings [ActiveRecord::Relation] Secret detection findings containing token information
      # @return [Hash] A hash mapping raw token values to their corresponding token objects
      #
      # This method:
      # 1. Groups findings by token type (PAT, Deploy Token, etc.)
      # 2. Performs separate lookups for each token type using the appropriate lookup method
      # 3. Returns a combined hash of all found tokens indexed by their raw values
      def get_tokens_by_raw_token_value(findings)
        # organise detected tokens by type
        raw_token_values_by_token_type = findings.each_with_object({}) do |finding, result|
          finding_type = finding.token_type
          finding_type = SECRET_TYPE_MAPPING[finding_type]
          result[finding_type] = [] unless result[finding_type]
          result[finding_type] << finding.metadata['raw_source_code_extract']

          result
        end

        # Find tokens and index by raw token
        raw_token_values_by_token_type.each_with_object({}) do |(token_type, raw_token_values), result_hash|
          type_tokens = @token_lookup_service.find(token_type, raw_token_values) # rubocop:disable Gitlab/NoFindInWorkers -- find is not an active record find
          result_hash.merge!(type_tokens) if type_tokens
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
      def build_token_status_attributes_by_raw_token(findings)
        now = Time.current
        findings.each_with_object({}) do |finding, attr_by_raw_token|
          token_value = finding.metadata['raw_source_code_extract']

          next unless SECRET_TYPE_MAPPING.key?(finding.token_type)

          attr_by_raw_token[token_value] ||= []
          attr_by_raw_token[token_value] << build_finding_token_status_attributes(finding, now)
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
