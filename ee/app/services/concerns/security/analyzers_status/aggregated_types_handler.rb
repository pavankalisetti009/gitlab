# frozen_string_literal: true

module Security
  module AnalyzersStatus
    module AggregatedTypesHandler
      extend ActiveSupport::Concern

      TYPE_MAPPINGS = {
        secret_detection: {
          pipeline_type: :secret_detection_pipeline_based,
          setting_type: :secret_detection_secret_push_protection,
          setting_field: :secret_push_protection_enabled
        },
        container_scanning: {
          pipeline_type: :container_scanning_pipeline_based,
          setting_type: :container_scanning_for_registry,
          setting_field: :container_scanning_for_registry_enabled
        }
      }.freeze

      STATUS_PRIORITY = {
        failed: 2,
        success: 1,
        not_configured: 0
      }.freeze

      def build_aggregated_type_status(project, analyzer_type, status)
        return unless aggregated_type_for(analyzer_type).present? && project.present?

        calculate_updated_aggregated_status(project, analyzer_type, status)
      end

      private

      def aggregated_type_for(analyzer_type)
        TYPE_MAPPINGS.find do |_, config|
          [config[:pipeline_type], config[:setting_type]].include?(analyzer_type)
        end&.first
      end

      def calculate_updated_aggregated_status(project, analyzer_type, status)
        analyzer_statuses = project.analyzer_statuses
        aggregated_type = aggregated_type_for(analyzer_type)
        other_type = find_other_type(aggregated_type, analyzer_type)
        return unless other_type.present? && aggregated_type.present?

        aggregated_status = extract_analyzer_status(analyzer_statuses, aggregated_type)
        other_status = extract_analyzer_status(analyzer_statuses, other_type)

        wanted_aggregated_status = higher_priority_between(status, other_status)
        return if aggregated_status == wanted_aggregated_status

        build_analyzer_status_hash(project, aggregated_type, wanted_aggregated_status)
      end

      def higher_priority_between(status_1, status_2)
        status_priority(status_1) > status_priority(status_2) ? status_1 : status_2
      end

      def build_analyzer_status_hash(project, type, status, build = nil)
        {
          project_id: project.id,
          traversal_ids: project.namespace.traversal_ids,
          analyzer_type: type,
          status: status,
          last_call: build&.started_at || build&.created_at || Time.current,
          archived: project.archived,
          build_id: build&.id
        }
      end

      def status_priority(status)
        STATUS_PRIORITY[status] || -1
      end

      def find_other_type(aggregated_type, current_analyzer_type)
        config = TYPE_MAPPINGS[aggregated_type]
        return config[:setting_type] if config[:pipeline_type] == current_analyzer_type
        return config[:pipeline_type] if config[:setting_type] == current_analyzer_type

        nil
      end

      def extract_analyzer_status(analyzer_statuses, type)
        analyzer_statuses.find { |s| s.analyzer_type.to_sym == type }&.status&.to_sym
      end
    end
  end
end
