# frozen_string_literal: true

module Ai
  module Catalog
    class FlowDefinition < BaseDefinition
      def agent_version_mappings
        workflow_steps.filter_map do |step|
          agent = agent_map[step['agent_id']]

          {
            agent: agent,
            version: resolve_agent_version(step)
          }
        end
      end

      def agents
        agent_map.values
      end

      private

      def agent_map
        @agent_map ||= preload_agents_by_id
      end

      def workflow_steps
        resolved_version.def_steps
      end

      def preload_agents_by_id
        agent_ids = workflow_steps.pluck('agent_id') # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- this is fetching data from a jsonb column.
        agents = Ai::Catalog::Item.where(id: agent_ids)
        agents.index_by(&:id)
      end

      def resolve_agent_version(step)
        step['pinned_version_prefix']
      end
    end
  end
end
