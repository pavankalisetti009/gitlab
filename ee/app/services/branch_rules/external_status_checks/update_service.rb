# frozen_string_literal: true

module BranchRules
  module ExternalStatusChecks
    class UpdateService < BaseService
      private

      def action_name
        'update'
      end

      def execute_on_branch_rule
        ::ExternalStatusChecks::UpdateService.new(
          container: project,
          current_user: current_user,
          params: params.merge(protected_branch_ids: [branch_rule.id])
        ).execute(skip_authorization: true)
      rescue ActiveRecord::RecordNotFound => exception
        ServiceResponse.error(
          message: exception.message,
          payload: { errors: ['Not found'] },
          reason: :not_found
        )
      end

      def permitted_params
        %i[check_id name external_url shared_secret]
      end
    end
  end
end
