# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module Flow
        class Execute < BaseMutation
          graphql_name 'AiCatalogFlowExecute'

          argument :flow_id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Global ID of the AI catalog flow to execute.'

          argument :flow_version_id, ::Types::GlobalIDType[::Ai::Catalog::ItemVersion],
            required: false,
            description: 'Global ID of the specific flow version to use. If not provided,
                        the latest version will be used.'

          field :flow_config, GraphQL::Types::String,
            null: true,
            description: 'YAML configuration that can be used in Duo workflow service for flow execution.'

          field :workflow, Types::Ai::DuoWorkflows::WorkflowType,
            null: true,
            description: 'Created workflow.'

          authorize :execute_ai_catalog_item_version

          def resolve(flow_id:, flow_version_id: nil)
            flow = GitlabSchema.object_from_id(flow_id).sync
            flow_version = authorized_find!(flow:, flow_version_id:)

            result = ::Ai::Catalog::Flows::ExecuteService.new(
              project: flow.project,
              current_user: current_user,
              params: {
                flow: flow,
                flow_version: flow_version,
                event_type: 'manual',
                execute_workflow: true
              }
            ).execute

            {
              flow_config: result.payload[:flow_config],
              workflow: result.payload[:workflow],
              errors: result.errors
            }
          end

          private

          def find_object(flow:, flow_version_id:)
            return if flow.nil?

            if flow_version_id.present?
              GitlabSchema.object_from_id(flow_version_id).sync
            else
              flow.latest_version
            end
          end
        end
      end
    end
  end
end
