# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Persistence
        class WorkspacesToBeReturnedFinder
          include UpdateTypes

          # @param [Hash] context
          # @return [Hash]
          def self.find(context)
            context => {
              agent: agent, # Skip type checking so we can use fast_spec_helper in the unit test spec
              update_type: String => update_type,
              workspaces_from_agent_infos: Array => workspaces_from_agent_infos,
            }

            workspaces_to_be_returned_query =
              generate_workspaces_to_be_returned_query(
                agent: agent,
                update_type: update_type,
                workspaces_from_agent_infos: workspaces_from_agent_infos
              )

            workspaces_to_be_returned = workspaces_to_be_returned_query.to_a

            context.merge(
              workspaces_to_be_returned: workspaces_to_be_returned
            )
          end

          # @param [Clusters::Agent] agent
          # @param [String] update_type
          # @param [Array] workspaces_from_agent_infos
          # @return [ActiveRecord::Relation]
          def self.generate_workspaces_to_be_returned_query(agent:, update_type:, workspaces_from_agent_infos:)
            # For a FULL update, return all workspaces for the agent which exist in the database
            if update_type == FULL
              return agent
                       .workspaces.desired_state_not_terminated
                       .or(agent.workspaces.actual_state_not_terminated)
                       .order_id_asc
            end

            # For a PARTIAL update, return:
            # 1. Workspaces with_desired_state_updated_more_recently_than_last_response_to_agent
            # 2. Workspaces with_desired_state_terminated_and_actual_state_not_terminated
            # 3. Workspaces which we received from the agent in the agent_infos array
            # 4. Workspaces which have force_include_all_resources set to true
            workspaces_from_agent_infos_ids = workspaces_from_agent_infos.map(&:id)
            agent
              .workspaces
              .with_desired_state_updated_more_recently_than_last_response_to_agent
              .or(agent.workspaces.with_desired_state_terminated_and_actual_state_not_terminated)
              .or(agent.workspaces.id_in(workspaces_from_agent_infos_ids))
              .or(agent.workspaces.forced_to_include_all_resources)
              .order_id_asc
          end
          private_class_method :generate_workspaces_to_be_returned_query
        end
      end
    end
  end
end
