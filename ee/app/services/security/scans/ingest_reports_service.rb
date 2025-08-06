# frozen_string_literal: true

module Security
  module Scans
    class IngestReportsService
      include Gitlab::ExclusiveLeaseHelpers

      TTL_REPORT_INGESTION = 1.hour

      def self.execute(pipeline)
        new(pipeline).execute
      end

      def initialize(pipeline)
        @pipeline = pipeline
      end

      def execute
        return unless pipeline.all_security_jobs_complete?

        return if already_ingested?

        if pipeline.project.can_store_security_reports?
          ::Security::StoreScansWorker.perform_async(pipeline.id)
          ::Security::ProcessScanEventsWorker.perform_async(pipeline.id)
        else
          ::Sbom::ScheduleIngestReportsService.new(pipeline).execute
          ::Ci::CompareSecurityReportsService.set_security_mr_widget_to_ready(pipeline_id: pipeline.id)
        end
      end

      private

      attr_reader :pipeline

      def scans_cache_key
        sha = pipeline.latest_builds.select(&:security_job?)
              .sort_by(&:id)
              .map { |build| "#{build.id}:#{build.updated_at}" }
              .join('|')
              .then { |value| Digest::SHA512.hexdigest(value) }
        "security:report:ingest:#{sha}"
      end

      def already_ingested?
        ::Gitlab::Redis::SharedState.with do |redis|
          !redis.set(scans_cache_key, 'OK', nx: true, ex: TTL_REPORT_INGESTION)
        end
      end
    end
  end
end
