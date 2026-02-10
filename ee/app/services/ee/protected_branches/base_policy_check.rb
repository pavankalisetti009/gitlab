# frozen_string_literal: true

module EE
  module ProtectedBranches # rubocop:disable Gitlab/BoundedContexts -- TODO: Namespacing
    class BasePolicyCheck
      def self.check!(...)
        new(...).check!
      end

      def initialize(protected_branch, params)
        @protected_branch = protected_branch
        @params = params
      end

      def check!
        raise ::Gitlab::Access::AccessDeniedError if violated?
      end

      def violated?
        raise NotImplementedError
      end

      private

      attr_reader :protected_branch, :params

      def policy_rules_apply?(policy)
        matched_git_branches(policy).any? do |git_branch|
          protected_branch.matches?(git_branch)
        end
      end

      def matched_git_branches(policy)
        # `PolicyBranchesService` returns the empty set if the project has an
        # empty repository. But we still must block modification of branch
        # protections whose name is literally matched by a policy's `branches`.
        if protected_branch.project.empty_repo?
          # rubocop:disable CodeReuse/ActiveRecord -- Plucking a bounded result set
          return protected_branch.project.protected_branches.limit(ProtectedBranchesFinder::LIMIT).pluck(:name)
          # rubocop:enable CodeReuse/ActiveRecord
        end

        policy_branches_service.scan_result_branches(
          # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- Policy link count per project is limited
          # rubocop:disable CodeReuse/ActiveRecord -- Plucking a limited relation
          policy.approval_policy_rules.pluck(:content).map(&:deep_symbolize_keys)
          # rubocop:enable CodeReuse/ActiveRecord
          # rubocop:enable Database/AvoidUsingPluckWithoutLimit
        )
      end

      def policy_branches_service
        @policy_branches_service ||= Security::SecurityOrchestrationPolicies::PolicyBranchesService
                                       .new(project: protected_branch.project)
      end
    end
  end
end
