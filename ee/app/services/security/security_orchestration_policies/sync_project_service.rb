# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncProjectService
      include Gitlab::Utils::StrongMemoize

      def initialize(security_policy:, project:, policy_changes:)
        @security_policy = security_policy
        @project = project
        @policy_changes = policy_changes
      end

      def execute
        return handle_policy_changes if policy_diff.any_changes?

        link_project_policy
      end

      private

      def policy_diff
        Security::SecurityOrchestrationPolicies::PolicyDiff::Diff.from_json(
          policy_changes[:diff], policy_changes[:rules_diff]
        )
      end
      strong_memoize_attr :policy_diff

      def handle_policy_changes
        if policy_disabled? || policy_unscoped?
          security_policy.unlink_project!(project)
        else
          update_project_approval_policy_rule_links
        end
      end

      def link_project_policy
        return unless security_policy.enabled

        security_policy.link_project!(project)
      end

      def update_project_approval_policy_rule_links
        deleted_rules = find_policy_rules(policy_diff.rules_diff.deleted.map(&:id))
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- created is an array of objects
        created_rules = find_policy_rules(policy_diff.rules_diff.created.pluck(:id))
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord

        security_policy.update_project_approval_policy_rule_links(project, created_rules, deleted_rules)
      end

      def find_policy_rules(policy_rule_ids)
        security_policy.approval_policy_rules.id_in(policy_rule_ids)
      end

      def policy_disabled?
        policy_diff.status_changed? && !security_policy.enabled?
      end

      def policy_unscoped?
        policy_diff.scope_changed? && !security_policy.scope_applicable?(project)
      end

      attr_accessor :security_policy, :project, :policy_changes
    end
  end
end
