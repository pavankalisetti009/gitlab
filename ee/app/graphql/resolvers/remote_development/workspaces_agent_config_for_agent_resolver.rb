# frozen_string_literal: true

module Resolvers
  module RemoteDevelopment
    class WorkspacesAgentConfigForAgentResolver < ::Resolvers::BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include LooksAhead

      type Types::RemoteDevelopment::WorkspacesAgentConfigType, null: true

      alias_method :agent, :object

      #
      # Resolve the workspaces agent config for the given agent.
      #
      # @param [Hash] **_args The arguments passed to the resolver, and do not in use here
      #
      # @return [WorkspacesAgentConfig] The workspaces agent config for the given agent
      #
      def resolve_with_lookahead(**_args)
        unless License.feature_available?(:remote_development)
          raise_resource_not_available_error! "'remote_development' licensed feature is not available"
        end

        raise Gitlab::Access::AccessDeniedError unless can_read_workspaces_agent_config?

        BatchLoader::GraphQL.for(agent.id).batch do |agent_ids, loader|
          agent_configs = ::RemoteDevelopment::AgentConfigsFinder.execute(
            current_user: current_user,
            cluster_agent_ids: agent_ids
          )
          apply_lookahead(agent_configs).each do |agent_config|
            loader.call(agent_config.cluster_agent_id, agent_config)
          end
        end
      end

      private

      def can_read_workspaces_agent_config?
        # noinspection RubyNilAnalysis - This is because the superclass #current_user uses #[], which can return nil
        current_user.can?(:read_cluster_agent, agent)
      end
    end
  end
end
