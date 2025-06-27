# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class WorkflowType < Types::BaseObject
        graphql_name 'DuoWorkflow'
        description 'A Duo Workflow'
        present_using ::Ai::DuoWorkflows::WorkflowPresenter
        authorize :read_duo_workflow

        def self.authorization_scopes
          [:api, :read_api, :ai_features, :ai_workflows]
        end

        field :id, type: GraphQL::Types::ID,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'ID of the workflow.'

        # The user id will always be the current_user.id as
        # only workflow owners can read a workflow
        field :user_id, Types::GlobalIDType[User],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'ID of the user.'

        field :project_id, Types::GlobalIDType[Project],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'ID of the project.'

        field :project, Types::ProjectType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: "Project that the workflow is in."

        field :human_status, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'Human-readable status of the workflow.'

        field :created_at, Types::TimeType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'Timestamp of when the workflow was created.'

        field :updated_at, Types::TimeType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'Timestamp of when the workflow was last updated.'

        field :goal, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Goal of the workflow.'

        field :workflow_definition, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Duo Workflow type based on its capabilities.'

        field :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Environment, e.g., ide or web.'

        field :agent_privileges_names, [GraphQL::Types::String],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Privileges granted to the agent during workflow execution.'

        field :pre_approved_agent_privileges_names, [GraphQL::Types::String],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Privileges pre-approved for the agent during workflow execution.'

        field :mcp_enabled, GraphQL::Types::Boolean,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Has MCP been enabled for the namespace.'

        field :allow_agent_to_request_user, GraphQL::Types::Boolean,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Allow the agent to request user input.'

        field :status, Types::Ai::DuoWorkflows::WorkflowStatusEnum,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Status of the workflow.'

        field :status_name, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Status Name of the workflow.'

        field :first_checkpoint, Types::Ai::DuoWorkflows::WorkflowEventType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: "First checkpoint of the workflow."
      end
    end
  end
end
