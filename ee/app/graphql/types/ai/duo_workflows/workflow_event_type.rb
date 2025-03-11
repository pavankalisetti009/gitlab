# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class WorkflowEventType < Types::BaseObject
        graphql_name 'DuoWorkflowEvent'
        description "Events that describe the history and progress of a Duo Workflow"
        present_using ::Ai::DuoWorkflows::WorkflowCheckpointEventPresenter
        authorize :read_duo_workflow_event

        def self.authorization_scopes
          [:api, :read_api, :ai_features]
        end

        field :checkpoint, Types::JsonStringType,
          description: 'Checkpoint of the event.'

        field :metadata, Types::JsonStringType,
          description: 'Metadata associated with the event.'

        field :workflow_status, Types::Ai::DuoWorkflows::WorkflowStatusEnum,
          description: 'Status of the workflow.'

        field :execution_status, GraphQL::Types::String,
          null: false, description: 'Granular status of workflow execution.',
          experiment: { milestone: '17.10' }

        field :timestamp, Types::TimeType,
          description: 'Time of the event.'

        field :parent_timestamp, Types::TimeType,
          description: 'Time of the parent event.'

        field :errors, [GraphQL::Types::String],
          null: true, description: 'Message errors.'

        # rubocop:disable GraphQL/ExtractType -- no need to extract two fields into a separate field
        field :workflow_goal, GraphQL::Types::String,
          description: 'Goal of the workflow.'

        field :workflow_definition, GraphQL::Types::String,
          description: 'Duo Workflow type based on its capabilities.'
        # rubocop:enable GraphQL/ExtractType -- we want to keep this way for backwards compatibility
      end
    end
  end
end
