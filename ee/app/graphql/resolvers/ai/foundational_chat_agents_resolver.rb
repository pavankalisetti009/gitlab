# frozen_string_literal: true

module Resolvers
  module Ai
    class FoundationalChatAgentsResolver < BaseResolver
      description 'AI foundational chat agents.'

      type ::Types::Ai::FoundationalChatAgentType.connection_type, null: true

      argument :project_id, ::Types::GlobalIDType[Project],
        required: false,
        description: 'Global ID of the project where the chat is present.'

      argument :namespace_id, ::Types::GlobalIDType[::Namespace],
        required: false,
        description: 'Global ID of the namespace where the chat is present.'

      def resolve(*, project_id: nil, namespace_id: nil)
        enabled_agents = if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
                           enabled_foundational_agents_in_namespace(
                             resolve_namespace(current_user, namespace_id, project_id),
                             current_user
                           )
                         else
                           enabled_foundational_agents_in_organization(
                             ::Organizations::Organization.default_organization
                           )
                         end

        filtered_agents = []
        filtered_agents << 'analytics_agent' if Feature.disabled?(:foundational_analytics_agent, current_user)

        enabled_agents
          .select { |agent| filtered_agents.exclude?(agent.reference) }
          .sort_by(&:id)
      end

      private

      def resolve_namespace(current_user, namespace_id, project_id)
        return unless current_user

        # use_billable_namespace
        # once https://gitlab.com/gitlab-org/gitlab/-/issues/580901 is implemented,
        # this should be moved to the source of truth
        current_user.user_preference.duo_default_namespace_with_fallback ||
          find_object(project_id || namespace_id)&.root_ancestor
      end

      def enabled_foundational_agents_in_namespace(namespace, current_user)
        unless namespace && Ability.allowed?(current_user, :read_namespace, namespace)
          return ::Ai::FoundationalChatAgent.only_duo_chat_agent
        end

        namespace.enabled_foundational_agents
      end

      def enabled_foundational_agents_in_organization(organization)
        organization.enabled_foundational_agents
      end

      def find_object(id)
        return unless id

        ::Gitlab::Graphql::Lazy.force(GitlabSchema.object_from_id(id))
      end
    end
  end
end
