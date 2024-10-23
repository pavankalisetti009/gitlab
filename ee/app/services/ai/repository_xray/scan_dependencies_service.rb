# frozen_string_literal: true

module Ai
  module RepositoryXray
    # This service scans and parses dependency manager configuration files on the repository's default
    # branch. The extracted data is stored in the `XrayReport` model. To reduce redundancy and load on
    # Gitaly, we use an exclusive lease guard to avoid parallel processing on the same project.
    class ScanDependenciesService
      include ExclusiveLeaseGuard

      # We expect this service will complete within 5 minutes in any repo
      LEASE_TIMEOUT = 5.minutes
      WORKER_CLASS = Ai::RepositoryXray::ScanDependenciesWorker

      def initialize(project)
        @project = project
      end

      def execute
        response = try_obtain_lease { process }

        # The worker's deduplication settings normally prevent a situation where we
        # can't obtain the lease; however, should it occur, we reschedule the worker.
        response || reschedule_worker
      end

      private

      attr_reader :project

      def process
        config_files = Ai::Context::Dependencies::ConfigFileParser.new(project).extract_config_files
        return ServiceResponse.success(message: 'No dependency config files found') if config_files.none?

        valid_config_files = config_files.select(&:valid?)
        invalid_config_files = config_files - valid_config_files

        save_xray_reports(valid_config_files) if valid_config_files.any?

        build_response(valid_config_files, invalid_config_files)
      end

      def save_xray_reports(config_files)
        config_files_by_lang = config_files.group_by { |cf| cf.class.lang }
        # TODO: `file_checksum` to be removed in https://gitlab.com/gitlab-org/gitlab/-/issues/479185.
        file_checksum = config_files.first.payload[:checksum]

        reports_array = config_files_by_lang.map do |(lang, config_files)|
          {
            project_id: project.id,
            payload: merge_payloads(config_files),
            lang: lang,
            file_checksum: file_checksum
          }
        end

        Projects::XrayReport.upsert_all(reports_array, unique_by: [:project_id, :lang])
      end

      # TODO: We're not concerned with the value of `fileName` nor `checksum` because they are
      # not utilized and will be removed in https://gitlab.com/gitlab-org/gitlab/-/issues/479185.
      def merge_payloads(config_files)
        config_files.each_with_object({ file_paths: [], libs: [] }) do |config_file, merged|
          merged[:libs].concat(config_file.payload[:libs])
          merged[:file_paths] << config_file.payload[:fileName]
        end
      end

      def build_response(valid_config_files, invalid_config_files)
        dependency_counts = []

        success_messages = valid_config_files.map do |config_file|
          payload = config_file.payload
          dependency_counts << payload[:libs].size
          "Found #{dependency_counts.last} dependencies in `#{payload[:fileName]}` (#{class_name(config_file)})"
        end

        error_messages = invalid_config_files.map do |config_file|
          "#{config_file.error_message} (#{class_name(config_file)})"
        end

        response_hash = {
          message: "Found #{(success_messages + error_messages).size} dependency config files",
          payload: {
            success_messages: success_messages,
            error_messages: error_messages,
            max_dependency_count: dependency_counts.max.to_i
          }
        }

        if error_messages.any?
          response_hash[:message] += ", #{error_messages.size} had errors"
          ServiceResponse.error(**response_hash)
        else
          ServiceResponse.success(**response_hash)
        end
      end

      def reschedule_worker
        WORKER_CLASS.perform_in(LEASE_TIMEOUT, project.id)

        ServiceResponse.error(
          message: "Lease taken. Rescheduled worker `#{WORKER_CLASS.name}`",
          payload: { lease_key: lease_key }
        )
      end

      def class_name(obj)
        obj.class.name.demodulize
      end

      def lease_key
        "#{self.class.name}:project_#{project.id}"
      end

      def lease_timeout
        LEASE_TIMEOUT
      end
    end
  end
end
