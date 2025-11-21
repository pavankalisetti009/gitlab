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
        unless can_use_foundational_chat_agents?(project_id, namespace_id)
          return ::Ai::FoundationalChatAgent.only_duo_chat_agent
        end

        filtered_agents = []
        filtered_agents << 'duo_planner' if Feature.disabled?(:foundational_duo_planner, current_user)
        filtered_agents << 'analytics_agent' if Feature.disabled?(:foundational_analytics_agent, current_user)

        ::Ai::FoundationalChatAgent.all
          .select { |agent| filtered_agents.exclude?(agent.reference) }
          .sort_by(&:id)
      end

      private

      def can_use_foundational_chat_agents?(project_id, namespace_id)
        if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          namespace = current_user.user_preference.get_default_duo_namespace

          return can_namespace_use_foundational_chat_agents?(namespace, current_user) if namespace

          return can_project_use_foundational_chat_agents?(find_object(project_id), current_user) if project_id

          can_namespace_use_foundational_chat_agents?(find_object(namespace_id), current_user)
        else
          ::Feature.enabled?(:duo_foundational_agents_availability, :instance) &&
            ::Ai::Setting.instance&.foundational_agents_default_enabled
        end
      end

      def can_namespace_use_foundational_chat_agents?(namespace, current_user)
        root_namespace = namespace&.root_ancestor

        return false unless root_namespace && Ability.allowed?(current_user, :read_namespace, root_namespace)

        ::Feature.enabled?(:duo_foundational_agents_availability, root_namespace) &&
          root_namespace.foundational_agents_default_enabled
      end

      def can_project_use_foundational_chat_agents?(project, current_user)
        ::Ability.allowed?(current_user, :read_project, project) &&
          can_namespace_use_foundational_chat_agents?(project.parent, current_user)
      end

      def find_object(id)
        return unless id

        ::Gitlab::Graphql::Lazy.force(GitlabSchema.object_from_id(id))
      end
    end
  end
end
