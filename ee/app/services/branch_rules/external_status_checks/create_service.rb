# frozen_string_literal: true

module BranchRules
  module ExternalStatusChecks
    class CreateService < BaseService
      def execute(skip_authorization: false)
        super
      rescue Gitlab::Access::AccessDeniedError
        ServiceResponse.error(
          message: 'Failed to create rule',
          payload: { errors: ['Not allowed'] },
          reason: :access_denied
        )
      end

      private

      def authorized?
        can?(current_user, :update_branch_rule, branch_rule)
      end

      def execute_on_branch_rule
        ::ExternalStatusChecks::CreateService.new(
          container: project,
          current_user: current_user,
          params: params.merge(protected_branch_ids: [branch_rule.id])
        ).execute(skip_authorization: true)
      end

      def execute_on_all_branches_rule
        ServiceResponse.error(message: 'All branch rules cannot configure external status checks')
      end

      def execute_on_all_protected_branches_rule
        ServiceResponse.error(message: 'All protected branch rules cannot configure external status checks')
      end

      def permitted_params
        %i[name external_url shared_secret]
      end
    end
  end
end
