# frozen_string_literal: true

module Security
  class MergeRequestSecurityReportGenerationService
    include Gitlab::Utils::StrongMemoize
    include ReactiveCaching

    DEFAULT_FINDING_STATE = 'detected'
    ALLOWED_REPORT_TYPES = %w[sast secret_detection container_scanning
      dependency_scanning dast coverage_fuzzing api_fuzzing].freeze

    InvalidReportTypeError = Class.new(ArgumentError)

    self.reactive_cache_work_type = :no_dependency
    self.reactive_cache_worker_finder = ->(id, params) { from_cache(id, params) }

    def self.execute(merge_request, params)
      new(merge_request, params).execute
    end

    def self.from_cache(merge_request_id, params)
      merge_request = ::MergeRequest.find_by_id(merge_request_id)

      return unless merge_request

      new(merge_request, params)
    end

    def initialize(merge_request, params)
      @merge_request = merge_request
      @params = params.to_h.symbolize_keys
    end

    def execute
      return report unless report_available?

      set_states_and_severities_of!(added_findings)
      set_states_and_severities_of!(fixed_findings)

      report
    end

    delegate :project, :id, to: :merge_request

    private

    attr_reader :merge_request, :params

    def report_type
      params[:report_type]
    end

    def report_available?
      report[:status] == :parsed
    end

    def set_states_and_severities_of!(findings)
      findings.each do |finding|
        vulnerability_data = existing_vulnerabilities[finding['uuid']]
        finding['state'] = vulnerability_data&.dig(:state) || DEFAULT_FINDING_STATE
        finding['severity'] = vulnerability_data&.dig(:severity) || finding['severity']
        finding['severity_override'] = vulnerability_data&.dig(:severity_override)
      end
    end

    def existing_vulnerabilities
      @existing_vulnerabilities ||=
        Vulnerability
        .with_findings_by_uuid(finding_uuids)
        .with_latest_severity_override
        .to_h do |vulnerability|
          [
            vulnerability.finding.uuid,
            {
              severity: vulnerability.severity,
              state: vulnerability.state,
              id: vulnerability.id,
              severity_override: latest_severity_override(vulnerability)
            }
          ]
        end
    end

    def latest_severity_override(vulnerability)
      latest_override = vulnerability.latest_severity_override
      return unless latest_override

      latest_override.as_json(
        only: [:vulnerability_id, :created_at, :original_severity, :new_severity],
        methods: [:author_data]
      )
    end

    def finding_uuids
      (added_findings + fixed_findings).pluck('uuid') # rubocop:disable CodeReuse/ActiveRecord
    end

    def added_findings
      @added_findings ||= report.dig(:data, 'added')
    end

    def fixed_findings
      @fixed_findings ||= report.dig(:data, 'fixed')
    end

    strong_memoize_attr def report
      validate_report_type!

      return old_report if Feature.disabled?(:vulnerability_partial_scans, project)

      with_reactive_cache(params.stringify_keys) do |data|
        latest = Ci::CompareSecurityReportsService.new(project, nil, params).latest?(base_pipeline, head_pipeline, data)
        raise InvalidateReactiveCache unless latest

        data
      end || { status: :parsing }
    end

    def old_report
      case report_type
      when 'sast'
        merge_request.compare_sast_reports(nil)
      when 'secret_detection'
        merge_request.compare_secret_detection_reports(nil)
      when 'container_scanning'
        merge_request.compare_container_scanning_reports(nil)
      when 'dependency_scanning'
        merge_request.compare_dependency_scanning_reports(nil)
      when 'dast'
        merge_request.compare_dast_reports(nil)
      when 'coverage_fuzzing'
        merge_request.compare_coverage_fuzzing_reports(nil)
      when 'api_fuzzing'
        merge_request.compare_api_fuzzing_reports(nil)
      end
    end

    def validate_report_type!
      raise InvalidReportTypeError unless ALLOWED_REPORT_TYPES.include?(report_type)
    end

    def calculate_reactive_cache(cache_params)
      Ci::CompareSecurityReportsService
        .new(project, nil, cache_params.symbolize_keys)
        .execute(base_pipeline, head_pipeline)
    end

    def base_pipeline
      merge_request.comparison_base_pipeline(Ci::CompareSecurityReportsService)
    end

    def head_pipeline
      merge_request.diff_head_pipeline
    end
  end
end
