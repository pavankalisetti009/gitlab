# frozen_string_literal: true

module Resolvers
  module SecurityOrchestration # rubocop:disable Gitlab/BoundedContexts -- TODO: Namespacing
    class PoliciesSyncStatusResolver < BaseResolver
      type ::Types::GitlabSubscriptions::Security::PoliciesSyncUpdated, null: true

      argument :policy_configuration_id, ::Types::GlobalIDType[::Security::OrchestrationPolicyConfiguration],
        required: true,
        description: 'ID of the security orchestration policy configuration.'

      def authorized?(policy_configuration_id:)
        policy_configuration = find_policy_configuration(policy_configuration_id)

        return false unless policy_configuration

        policy_project = policy_configuration.security_policy_management_project

        return false unless current_user.can?(:update_security_orchestration_policy_project, policy_project)

        Feature.enabled?(:security_policy_sync_propagation_tracking, policy_project)
      end

      def resolve(policy_configuration_id:)
        policy_configuration = find_policy_configuration(policy_configuration_id)

        return {} unless policy_configuration

        ::Security::SecurityOrchestrationPolicies::PolicySyncState::State.new(policy_configuration.id).to_h
      end

      private

      def find_policy_configuration(id)
        ::Gitlab::Graphql::Lazy.force(GitlabSchema.find_by_gid(id))
      end
    end
  end
end
