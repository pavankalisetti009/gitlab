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

      def initialize(project)
        @project = project
      end

      def execute
        response = try_obtain_lease { process }

        response || ServiceResponse.success(message: 'Lease taken', payload: { lease_key: lease_key })
      end

      private

      attr_reader :project

      def process
        config_files = Ai::Context::Dependencies::ConfigFileParser.new(project).extract_config_files
        return ServiceResponse.success(message: 'No dependency config files found') if config_files.none?

        valid_config_files = config_files.select(&:valid?)
        invalid_config_files = config_files - valid_config_files

        success_messages = valid_config_files.map do |config_file|
          payload = config_file.payload
          "Found #{payload[:libs].size} dependencies in `#{payload[:fileName]}` (#{class_name(config_file)})"
        end

        error_messages = invalid_config_files.map do |config_file|
          "#{config_file.error_message} (#{class_name(config_file)})"
        end

        save_xray_reports(valid_config_files)

        build_response(success_messages, error_messages)
      end

      def save_xray_reports(config_files)
        reports_array = config_files.map do |config_file|
          payload = config_file.payload

          {
            project_id: project.id,
            payload: payload,
            lang: config_file.class.lang,
            file_checksum: payload[:checksum]
          }
        end

        Projects::XrayReport.upsert_all(reports_array, unique_by: [:project_id, :lang])
      end

      def build_response(success_messages, error_messages)
        response_hash = {
          message: "Found #{(success_messages + error_messages).size} dependency config files",
          payload: {
            success_messages: success_messages,
            error_messages: error_messages
          }
        }

        if error_messages.any?
          response_hash[:message] += ", #{error_messages.size} had errors"
          ServiceResponse.error(**response_hash)
        else
          ServiceResponse.success(**response_hash)
        end
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
