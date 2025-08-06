# frozen_string_literal: true

module Ai
  module Catalog
    class FlowDefinition < BaseDefinition
      def steps_with_agents_preloaded
        steps.filter_map do |step|
          agent = agent_map[step['agent_id']]

          step.except('agent_id').merge('agent' => agent).symbolize_keys
        end
      end

      def agents
        agent_map.values
      end

      private

      def agent_map
        @agent_map ||= preload_agents_by_id
      end

      def steps
        version.def_steps
      end

      def preload_agents_by_id
        agent_ids = steps.pluck('agent_id') # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- this is fetching data from a jsonb column.
        agents = Ai::Catalog::Item.where(id: agent_ids)
        agents.index_by(&:id)
      end
    end
  end
end
