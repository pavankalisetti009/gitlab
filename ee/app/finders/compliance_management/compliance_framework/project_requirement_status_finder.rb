# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ProjectRequirementStatusFinder
      LIMIT = 100

      def initialize(group, current_user)
        @group = group
        @current_user = current_user
      end

      def execute
        return model.none unless allowed?

        Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder.new(
          scope: model.order_by_updated_at_and_id(:desc),
          array_scope: group.self_and_descendant_ids,
          array_mapping_scope: model.method(:in_optimization_array_mapping_scope),
          finder_query: model.method(:in_optimization_finder_query)
        ).execute.limit(LIMIT)
      end

      private

      attr_reader :group, :current_user

      def allowed?
        Ability.allowed?(current_user, :read_compliance_adherence_report, group)
      end

      def model
        ::ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus
      end
    end
  end
end
