# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class DiffService
      def initialize(project, new_analyzer_statuses)
        @project = project
        @new_analyzer_statuses = new_analyzer_statuses
        @diff = {}
      end

      def execute
        process_new_statuses
        process_removed_statuses

        diff
      end

      attr_reader :project, :new_analyzer_statuses, :diff

      private

      def extract_processed_types
        new_analyzer_statuses.keys
      end

      def fetch_current_statuses
        @current_statuses ||= AnalyzerProjectStatus.by_projects(project).index_by(&:analyzer_type)
          .transform_keys(&:to_sym)
      end

      def process_new_statuses
        return unless new_analyzer_statuses.present?

        current_statuses = fetch_current_statuses
        new_analyzer_statuses.each do |analyzer_type, status_data|
          new_status = status_data[:status].to_s
          current_record = current_statuses[analyzer_type]
          old_status = current_record&.status.to_s

          update_diff_if_status_changed(analyzer_type, old_status, new_status)
        end
      end

      def process_removed_statuses
        current_statuses = fetch_current_statuses
        processed_types = extract_processed_types

        current_statuses.each do |type, record|
          old_status = record.status.to_s
          next if processed_types.include?(type) || old_status == 'not_configured'

          record_status_change(type, old_status, 'not_configured')
        end
      end

      def update_diff_if_status_changed(analyzer_type, old_status, new_status)
        return if new_status == old_status

        record_status_change(analyzer_type, old_status, new_status)
      end

      def record_status_change(analyzer_type, old_status, new_status)
        diff[analyzer_type] ||= {}
        diff[analyzer_type][new_status] ||= 0
        diff[analyzer_type][new_status] += 1

        return if old_status.empty?

        diff[analyzer_type][old_status] ||= 0
        diff[analyzer_type][old_status] -= 1
      end
    end
  end
end
