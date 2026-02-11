# frozen_string_literal: true

module Mutations
  module Ai
    module DuoWorkflows
      class UpdateToolCallApprovals < BaseMutation
        graphql_name 'UpdateDuoWorkflowToolCallApprovals'

        authorize :update_duo_workflow

        argument :workflow_id,
          ::Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: true,
          description: 'Global ID of the workflow to update.'

        argument :tool_name,
          GraphQL::Types::String,
          required: true,
          description: 'Name of the tool to approve.'

        argument :tool_call_args, # rubocop:disable Graphql/JSONType -- Different tools will have different call args
          GraphQL::Types::JSON,
          required: true,
          description: 'Arguments for the tool call.'

        field :workflow,
          Types::Ai::DuoWorkflows::WorkflowType,
          null: true,
          description: 'Updated workflow with new tool approvals.'

        field :errors,
          [GraphQL::Types::String],
          null: false,
          description: 'Errors encountered during update.'

        def resolve(workflow_id:, tool_name:, tool_call_args:)
          workflow = authorized_find!(id: workflow_id)

          result = ::Ai::DuoWorkflows::UpdateToolCallApprovalsService.new(
            workflow: workflow,
            tool_name: tool_name,
            tool_call_args: tool_call_args,
            current_user: current_user
          ).execute

          if result.success?
            { workflow: result.payload[:workflow], errors: [] }
          else
            { workflow: nil, errors: [result.message] }
          end
        end
      end
    end
  end
end
