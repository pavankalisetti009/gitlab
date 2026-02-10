# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ProtectedBranchesPushService < BaseProjectService
      include Gitlab::Utils::StrongMemoize

      def initialize(project:, ignore_warn_mode: false)
        super(project: project)
        @ignore_warn_mode = ignore_warn_mode
      end

      def execute
        PolicyBranchesService.new(project: project).scan_result_branches(rules)
      end

      private

      attr_reader :ignore_warn_mode

      def rules
        blocking_policies = applicable_active_policies.select do |rule|
          rule.dig(:approval_settings, :prevent_pushing_and_force_pushing)
        end

        blocking_policies.pluck(:rules).flatten # rubocop: disable CodeReuse/ActiveRecord -- TODO: blocking_policies is a Hash
      end

      def applicable_active_policies
        policy_scope_checker = ::Security::SecurityOrchestrationPolicies::PolicyScopeChecker.new(project: project)

        project
          .all_security_orchestration_policy_configurations
          .flat_map(&:active_scan_result_policies)
          .reject { |policy| policy_in_warn_mode?(policy) unless ignore_warn_mode }
          .select { |policy| policy_scope_checker.policy_applicable?(policy) }
      end

      def policy_in_warn_mode?(policy)
        policy[:enforcement_type] == Security::Policy::ENFORCEMENT_TYPE_WARN
      end
    end
  end
end
