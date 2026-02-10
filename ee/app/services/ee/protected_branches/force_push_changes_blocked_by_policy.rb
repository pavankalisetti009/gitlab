# frozen_string_literal: true

module EE
  module ProtectedBranches # rubocop:disable Gitlab/BoundedContexts -- TODO: Namespacing
    module ForcePushChangesBlockedByPolicy
      class ForcePushCheck < BasePolicyCheck
        def violated?
          forbidden_params?(protected_branch) && blocked?(protected_branch)
        end

        private

        def forbidden_params?(protected_branch)
          alters_allow_force_push?(protected_branch) || alters_push_access_levels?
        end

        def alters_allow_force_push?(protected_branch)
          return false unless params.key?(:allow_force_push)

          protected_branch.allow_force_push != params[:allow_force_push]
        end

        def alters_push_access_levels?
          params[:push_access_levels_attributes]&.any?
        end

        def blocked?(protected_branch)
          return false unless protected_branch.project_level?

          blocking_policies = protected_branch
            .project
            .security_policies
            .prevent_pushing_and_force_pushing
            .including_approval_policy_rules

          blocking_policies = blocking_policies.without_warn_mode

          blocking_policies.any? { |policy| policy_rules_apply?(policy) }
        end
      end

      def execute(protected_branch, skip_authorization: false)
        ForcePushCheck.check!(protected_branch, params)

        super
      end
    end
  end
end
