# frozen_string_literal: true

module BranchRules
  module ExternalStatusChecks
    class CreateService < BaseService
      private

      def action_name
        'create'
      end

      def execute_on_branch_rule
        ::ExternalStatusChecks::CreateService.new(
          container: project,
          current_user: current_user,
          params: params.merge(protected_branch_ids: [branch_rule.id])
        ).execute(skip_authorization: true)
      end

      def permitted_params
        %i[name external_url shared_secret]
      end
    end
  end
end
