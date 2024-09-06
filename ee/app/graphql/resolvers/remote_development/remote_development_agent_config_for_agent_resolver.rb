# frozen_string_literal: true

# TODO: clusterAgent.remoteDevelopmentAgentConfig GraphQL is deprecated - remove in 17.10 - https://gitlab.com/gitlab-org/gitlab/-/issues/480769
module Resolvers
  module RemoteDevelopment
    class RemoteDevelopmentAgentConfigForAgentResolver < ::Resolvers::BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include LooksAhead

      type Types::RemoteDevelopment::RemoteDevelopmentAgentConfigType, null: true

      alias_method :agent, :object

      #
      # Resolve the remote development agent config for the given agent.
      #
      # @param [Hash] **_args The arguments passed to the resolver, and do not in use here
      #
      # @return [RemoteDevelopmentAgentConfig] The remote development agent config for the given agent
      #
      def resolve_with_lookahead(**_args)
        unless License.feature_available?(:remote_development)
          raise_resource_not_available_error! "'remote_development' licensed feature is not available"
        end

        raise Gitlab::Access::AccessDeniedError unless can_read_remote_development_agent_config?

        BatchLoader::GraphQL.for(agent.id).batch do |agent_ids, loader|
          agent_configs = ::RemoteDevelopment::RemoteDevelopmentAgentConfigsFinder.execute(
            current_user: current_user,
            cluster_agent_ids: agent_ids
          )
          apply_lookahead(agent_configs).each do |agent_config|
            loader.call(agent_config.cluster_agent_id, agent_config)
          end
        end
      end

      private

      def can_read_remote_development_agent_config?
        # noinspection RubyNilAnalysis - This is because the superclass #current_user uses #[], which can return nil
        current_user.can?(:read_cluster_agent, agent)
      end
    end
  end
end
