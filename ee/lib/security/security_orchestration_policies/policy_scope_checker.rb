# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PolicyScopeChecker
      def initialize(project:)
        @project = project
      end

      def policy_applicable?(policy)
        return false if policy.blank?

        applicable_for_compliance_framework?(policy) && applicable_for_project?(policy) && applicable_for_group?(policy)
      end

      private

      attr_accessor :project

      def applicable_for_compliance_framework?(policy)
        policy_scope_compliance_frameworks = policy.dig(:policy_scope, :compliance_frameworks).to_a
        return true if policy_scope_compliance_frameworks.blank?

        compliance_framework_ids = project.compliance_framework_ids
        return false if compliance_framework_ids.blank?

        policy_scope_compliance_frameworks.any? { |framework| framework[:id].in?(compliance_framework_ids) }
      end

      def applicable_for_project?(policy)
        policy_scope_included_projects = policy.dig(:policy_scope, :projects, :including).to_a
        policy_scope_excluded_projects = policy.dig(:policy_scope, :projects, :excluding).to_a

        return false if policy_scope_excluded_projects.any? { |policy_project| policy_project[:id] == project.id }
        return true if policy_scope_included_projects.blank?

        policy_scope_included_projects.any? { |policy_project| policy_project[:id] == project.id }
      end

      def applicable_for_group?(policy)
        policy_scope_included_groups = policy.dig(:policy_scope, :groups, :including).to_a
        policy_scope_excluded_groups = policy.dig(:policy_scope, :groups, :excluding).to_a

        return true if policy_scope_included_groups.blank? && policy_scope_excluded_groups.blank?

        ancestor_group_ids = project.group&.self_and_ancestor_ids.to_a

        return false if policy_scope_excluded_groups.any? { |policy_group| policy_group[:id].in?(ancestor_group_ids) }
        return true if policy_scope_included_groups.blank?

        policy_scope_included_groups.any? { |policy_group| policy_group[:id].in?(ancestor_group_ids) }
      end
    end
  end
end
