# frozen_string_literal: true

module Ai
  # This service stores the artifacts produced by the Repository X-Ray CI job
  class StoreRepositoryXrayService
    include Gitlab::Utils::Gzip

    def initialize(pipeline)
      @pipeline = pipeline
    end

    def execute
      pipeline.job_artifacts.repository_xray.each do |artifact|
        artifact.each_blob do |blob, filename|
          lang = File.basename(filename, '.json')
          begin
            content = ::Gitlab::Json.parse(blob)
            Projects::XrayReport
              .upsert(
                { project_id: pipeline.project_id, payload: content, lang: lang, file_checksum: content['checksum'] },
                unique_by: [:project_id, :lang]
              )
          rescue JSON::ParserError => e
            self.class.log_event({ action: 'xray_report_parse', error: "Parsing failed #{e}" })
          end
        end
      end
    end

    private

    def self.log_event(log_fields)
      Gitlab::AppLogger.info(
        message: 'store_repository_xray',
        **log_fields
      )
    end

    attr_reader :pipeline
  end
end
