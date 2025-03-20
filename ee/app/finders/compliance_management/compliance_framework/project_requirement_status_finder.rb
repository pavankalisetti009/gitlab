# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ProjectRequirementStatusFinder
      LIMIT = 100

      def initialize(group, current_user, params = {})
        @group = group
        @current_user = current_user
        @params = params
      end

      def execute
        return model.none unless allowed?

        Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder.new(
          scope: in_operator_scope,
          array_scope: group.self_and_descendant_ids,
          array_mapping_scope: model.method(:in_optimization_array_mapping_scope),
          finder_query: model.method(:in_optimization_finder_query)
        ).execute.limit(LIMIT)
      end

      private

      attr_reader :group, :current_user, :params

      def allowed?
        Ability.allowed?(current_user, :read_compliance_adherence_report, group)
      end

      def model
        ::ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus
      end

      def in_operator_scope
        base_scope = model
        base_scope = filter_by_project(base_scope)
        base_scope = filter_by_requirement(base_scope)
        base_scope = filter_by_framework(base_scope)

        base_scope.order_by_updated_at_and_id(:desc)
      end

      def filter_by_project(status_records)
        return status_records.for_projects(params[:project_id]) if params[:project_id].present?

        status_records
      end

      def filter_by_requirement(status_records)
        return status_records.for_requirements(params[:requirement_id]) if params[:requirement_id].present?

        status_records
      end

      def filter_by_framework(status_records)
        return status_records.for_frameworks(params[:framework_id]) if params[:framework_id].present?

        status_records
      end
    end
  end
end
