# frozen_string_literal: true

module Subscriptions
  module Security
    class PoliciesSyncUpdated < ::Subscriptions::BaseSubscription
      include Gitlab::Graphql::Laziness

      payload_type Types::GitlabSubscriptions::Security::PoliciesSyncUpdated

      argument :policy_configuration_id, ::Types::GlobalIDType[::Security::OrchestrationPolicyConfiguration],
        required: true,
        description: 'ID of the security orchestration policy configuration.'

      def authorized?(policy_configuration_id:)
        policy_configuration = find_policy_configuration(policy_configuration_id) || unauthorized!

        if current_user.can?(:update_security_orchestration_policy_project,
          policy_configuration.security_policy_management_project)
          return true
        end

        unauthorized!
      end

      def update(_)
        {
          projects_progress: object[:projects_progress],
          projects_total: object[:projects_total],
          failed_projects: object[:failed_projects],
          merge_requests_progress: object[:merge_requests_progress],
          merge_requests_total: object[:merge_requests_total],
          in_progress: object[:in_progress]
        }
      end

      private

      def find_policy_configuration(id)
        force(GitlabSchema.find_by_gid(id))
      end
    end
  end
end
