# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class FlowStepsInputType < BaseInputObject
        graphql_name 'AiCatalogFlowStepsInput'

        argument :agent_id, ::Types::GlobalIDType[::Ai::Catalog::Item],
          prepare: ->(global_id, _ctx) { global_id.model_id.to_i },
          required: true,
          description: 'Agent to use.'

        argument :pinned_version_prefix, GraphQL::Types::String,
          required: false,
          description: 'Major version, minor version, or patch to pin the agent to.'
      end
    end
  end
end
