# frozen_string_literal: true

module Mutations
  module MergeRequests
    class DismissPolicyViolations < Base
      graphql_name 'DismissPolicyViolations'
      description 'Dismisses policy violations linked to a merge request'

      argument :security_policy_ids,
        [GraphQL::Types::ID],
        required: true,
        description: 'IDs of warn mode policies with violations to dismiss.'

      def resolve(project_path:, iid:, **args)
        merge_request = authorized_find!(project_path: project_path, iid: iid)

        result = ::Security::ScanResultPolicies::DismissPolicyViolationsService.new(
          merge_request,
          current_user: current_user,
          params: args.slice(:security_policy_ids)
        ).execute

        {
          errors: result.success? ? [] : [result.message]
        }
      end
    end
  end
end
