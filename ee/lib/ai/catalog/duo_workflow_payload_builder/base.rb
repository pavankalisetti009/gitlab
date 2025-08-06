# frozen_string_literal: true

module Ai
  module Catalog
    module DuoWorkflowPayloadBuilder
      class Base
        include Gitlab::Utils::StrongMemoize
        include ActiveModel::Model

        def initialize(flow_id, pinned_version_prefix = nil)
          @flow_id = flow_id
          @pinned_version_prefix = pinned_version_prefix
        end

        def build
          build_flow_config
        end

        private

        attr_reader :flow_id, :pinned_version_prefix

        def pinned_to_specific_version?
          # if the flow is pinned to a specific version, we pin all agent versions too
          pinned_version_prefix.to_s.count('.') == 2
        end

        def flow
          Ai::Catalog::Item.find(flow_id)
        end
        strong_memoize_attr :flow

        def flow_definition
          flow.definition(pinned_version_prefix)
        end
        strong_memoize_attr :flow_definition

        def agents
          flow_definition.agents
        end
        strong_memoize_attr :agents

        def steps_with_agents_preloaded
          flow_definition.steps_with_agents_preloaded
        end

        def agent_unique_identifier(agent)
          agent.id.to_s
        end
      end
    end
  end
end
