# frozen_string_literal: true

module Vulnerabilities
  class CompareSecurityReportsService < ::Ci::CompareReportsBaseService
    SECURITY_MR_WIDGET_POLLING_CACHE_TTL = 2.hours.in_seconds

    def self.transition_cache_key(pipeline_id: nil)
      return unless pipeline_id.present?

      "security_mr_widget::report_parsing_check::#{pipeline_id}:transitioning"
    end

    def self.ready_cache_key(pipeline_id: nil, report_type: nil)
      return unless pipeline_id.present?

      "security_mr_widget::report_parsing_check::#{report_type}::#{pipeline_id}"
    end

    def self.set_security_mr_widget_to_polling(pipeline_id: nil)
      return unless pipeline_id.present?

      Gitlab::Redis::SharedState.with do |redis|
        redis.set(
          transition_cache_key(pipeline_id:),
          pipeline_id,
          ex: SECURITY_MR_WIDGET_POLLING_CACHE_TTL
        )
      end
    end

    def self.set_security_report_type_to_ready(pipeline_id: nil, report_type: nil)
      return unless pipeline_id.present? && report_type.present?

      Gitlab::Redis::SharedState.with do |redis|
        redis.set(
          ready_cache_key(pipeline_id:, report_type:),
          pipeline_id,
          ex: SECURITY_MR_WIDGET_POLLING_CACHE_TTL
        )
      end
    end

    def self.set_security_mr_widget_to_ready(pipeline_id: nil)
      return unless pipeline_id.present?

      Gitlab::Redis::SharedState.with { |redis| redis.del(transition_cache_key(pipeline_id:)) }
    end

    def build_comparer(base_report, head_report)
      comparison_params = params.merge(
        base_report: base_report,
        head_report: head_report,
        partial_scan_scanner_ids: partial_scan_scanner_ids
      )
      comparer_class.new(project, comparison_params)
    end

    # For full scan comparisons where the head pipeline includes partial scans,
    # identify the scanners configured for partial scanning and filter out their
    # findings from the base pipeline. This prevents vulnerabilities detected by
    # those scanners in the base pipeline from incorrectly appearing as "fixed"
    # in the full scan tab, since they're already handled in the partial scan comparison.
    def partial_scan_scanner_ids
      return [] unless params[:scan_mode] == 'full'
      return [] if head_pipeline.nil?

      partial_scans = head_pipeline.security_scans.partial.to_a
      return Set.new if partial_scans.empty?

      build_type_pairs = partial_scans.map do |scan|
        file_type_value = ::Ci::JobArtifact.file_types[scan.scan_type]
        [scan.build_id, file_type_value]
      end

      artifacts = head_pipeline.job_artifacts
                               .security_reports_by_build_and_type_pairs(build_type_pairs)

      artifacts.filter_map do |artifact|
        artifact&.security_report&.scanner&.external_id
      end.to_set
    end

    def comparer_class
      Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer
    end

    def serializer_class
      Vulnerabilities::FindingDiffSerializer
    end

    def get_report(pipeline)
      # This is to delay polling in Projects::MergeRequestsController
      # until `Security::StoreFindingsService` is complete
      return :parsing unless ready_to_send_to_finder?(pipeline)

      findings = Security::FindingsFinder.new(
        pipeline,
        params: {
          report_type: [params[:report_type]],
          scope: 'all',
          scan_mode: scan_mode_for_pipeline(pipeline),
          limit: Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer::MAX_FINDINGS_COUNT
        }
      ).execute.with_api_scopes

      findings_array = findings.to_a
      Security::Finding.preload_auto_dismissal_checks!(project, findings_array)

      Gitlab::Ci::Reports::Security::AggregatedFinding.new(pipeline, findings_array)
    end

    def execute(base_pipeline, head_pipeline)
      @base_pipeline = base_pipeline
      @head_pipeline = head_pipeline
      super
    end

    private

    attr_reader :base_pipeline, :head_pipeline

    def scan_mode_for_pipeline(pipeline)
      # For partial scan comparisons, we want to compare full scan results from the base pipeline
      # against partial scan results from the head pipeline. This prevents existing vulnerabilities
      # from appearing as "new" when they're detected by partial scans on feature branches.
      if params[:scan_mode] == 'partial' && pipeline == base_pipeline
        'full'
      else
        params[:scan_mode]
      end
    end

    def ready_to_send_to_finder?(pipeline)
      return true if pipeline.nil? || report_type_ingested?(pipeline, params[:report_type])
      return false if ingesting_security_scans_for?(pipeline)

      build_ids = pipeline.builds
          .with_reports_of_type(params[:report_type])
          .pluck_primary_key

      !pipeline.security_scans
        .by_build_ids(build_ids)
        .by_scan_types(params[:report_type])
        .not_in_terminal_state
        .any?
    end

    def report_type_ingested?(pipeline, report_type)
      # rubocop:disable CodeReuse/ActiveRecord -- false positive
      Gitlab::Redis::SharedState.with do |redis|
        redis.exists?(
          self.class.ready_cache_key(pipeline_id: pipeline.id, report_type: report_type)
        )
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end

    def ingesting_security_scans_for?(pipeline)
      # rubocop:disable CodeReuse/ActiveRecord -- false positive
      Gitlab::Redis::SharedState.with do |redis|
        redis.exists?(self.class.transition_cache_key(pipeline_id: pipeline.id))
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end
  end
end
