# frozen_string_literal: true

module Security
  module InventoryFilters
    class ProjectsFinderService
      include ::Gitlab::Pagination::GraphqlKeysetPagination

      def initialize(namespace:, params: {})
        @namespace = namespace
        @params = params
      end

      def execute
        scope = build_filtered_scope
        result = paginate_with_keyset(scope)
        project_ids = result[:records].map(&:project_id)

        {
          ids: project_ids,
          page_info: result[:page_info]
        }
      end

      private

      attr_reader :namespace, :params

      def base_scope
        Security::InventoryFilter.within(namespace.traversal_ids).unarchived
      end

      def build_filtered_scope
        scope = base_scope
        scope = filter_by_vulnerability_counts(scope)
        scope = filter_by_analyzers_statuses(scope)
        scope = scope.order_by_traversal_and_project
        filter_by_search(scope)
      end

      def filter_by_vulnerability_counts(scope)
        return scope unless params[:vulnerability_count_filters].present?

        params[:vulnerability_count_filters].each do |filter|
          scope = scope.by_severity_count(filter[:severity], filter[:operator], filter[:count])
        end

        scope
      end

      def filter_by_analyzers_statuses(scope)
        return scope unless params[:security_analyzer_filters].present?

        params[:security_analyzer_filters].each do |filter|
          scope = scope.by_analyzer_status(filter[:analyzer_type], filter[:status])
        end

        scope
      end

      def filter_by_search(scope)
        return scope unless params[:search].present?

        scope.search(params[:search])
      end
    end
  end
end
