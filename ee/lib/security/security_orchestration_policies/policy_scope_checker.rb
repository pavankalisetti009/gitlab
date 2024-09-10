# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PolicyScopeChecker
      def initialize(project:)
        @project = project
      end

      def policy_applicable?(policy)
        return false if policy.blank?
        return true if policy[:policy_scope].blank?

        scope_applicable?(policy[:policy_scope])
      end

      def security_policy_applicable?(security_policy)
        return false if security_policy.blank?
        return true if security_policy.scope.blank?

        scope_applicable?(security_policy.scope.deep_symbolize_keys)
      end

      private

      attr_accessor :project

      def scope_applicable?(policy_scope)
        applicable_for_compliance_framework?(policy_scope) &&
          applicable_for_project?(policy_scope) &&
          applicable_for_group?(policy_scope)
      end

      def applicable_for_compliance_framework?(policy_scope)
        policy_scope_compliance_frameworks = policy_scope[:compliance_frameworks].to_a
        return true if policy_scope_compliance_frameworks.blank?

        compliance_framework_ids = project.compliance_framework_ids
        return false if compliance_framework_ids.blank?

        policy_scope_compliance_frameworks.any? { |framework| framework[:id].in?(compliance_framework_ids) }
      end

      def applicable_for_project?(policy_scope)
        policy_scope_included_projects = policy_scope.dig(:projects, :including).to_a
        policy_scope_excluded_projects = policy_scope.dig(:projects, :excluding).to_a

        return false if policy_scope_excluded_projects.any? { |policy_project| policy_project[:id] == project.id }
        return true if policy_scope_included_projects.blank?

        policy_scope_included_projects.any? { |policy_project| policy_project[:id] == project.id }
      end

      def applicable_for_group?(policy_scope)
        policy_scope_included_groups = policy_scope.dig(:groups, :including).to_a
        policy_scope_excluded_groups = policy_scope.dig(:groups, :excluding).to_a

        return true if policy_scope_included_groups.blank? && policy_scope_excluded_groups.blank?

        ancestor_group_ids = project.group&.self_and_ancestor_ids.to_a

        return false if policy_scope_excluded_groups.any? { |policy_group| policy_group[:id].in?(ancestor_group_ids) }
        return true if policy_scope_included_groups.blank?

        policy_scope_included_groups.any? { |policy_group| policy_group[:id].in?(ancestor_group_ids) }
      end
    end
  end
end
