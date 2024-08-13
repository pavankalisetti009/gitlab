# frozen_string_literal: true

module EE
  module Types
    module Clusters
      module AgentType
        extend ActiveSupport::Concern

        prepended do
          field :vulnerability_images,
            type: ::Types::Vulnerabilities::ContainerImageType.connection_type,
            null: true,
            description: 'Container images reported on the agent vulnerabilities.',
            resolver: ::Resolvers::Vulnerabilities::ContainerImagesResolver

          field :workspaces,
            ::Types::RemoteDevelopment::WorkspaceType.connection_type,
            null: true,
            resolver: ::Resolvers::RemoteDevelopment::WorkspacesForAgentResolver,
            description: 'Workspaces associated with the agent.'

          field :remote_development_agent_config,
            ::Types::RemoteDevelopment::RemoteDevelopmentAgentConfigType,
            extras: [:lookahead],
            null: true,
            description: 'Remote development agent config for the cluster agent.',
            resolver: ::Resolvers::RemoteDevelopment::AgentConfigForAgentResolver
        end
      end
    end
  end
end
