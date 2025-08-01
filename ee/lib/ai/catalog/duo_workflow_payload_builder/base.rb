# frozen_string_literal: true

module Ai
  module Catalog
    module DuoWorkflowPayloadBuilder
      class Base
        include Gitlab::Utils::StrongMemoize
        include ActiveModel::Model

        def initialize(flow_id, version = nil)
          @flow_id = flow_id
          @version = version
        end

        def build
          build_flow_config
        end

        private

        attr_reader :flow_id, :version

        def flow
          Ai::Catalog::Item.find(flow_id)
        end
        strong_memoize_attr :flow

        def flow_definition
          flow.definition(version)
        end
        strong_memoize_attr :flow_definition

        def agents
          flow_definition.agents
        end
        strong_memoize_attr :agents

        def agent_version_mappings
          flow_definition.agent_version_mappings
        end

        def agent_unique_identifier(agent)
          agent.id.to_s
        end
      end
    end
  end
end
