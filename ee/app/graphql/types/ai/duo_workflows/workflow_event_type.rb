# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class WorkflowEventType < Types::BaseObject
        graphql_name 'DuoWorkflowEvent'
        description "Events that describe the history and progress of a Duo Workflow"
        present_using ::Ai::DuoWorkflows::WorkflowCheckpointEventPresenter
        authorize :read_duo_workflow_event

        field :checkpoint, Types::JsonStringType,
          scopes: [:api, :read_api, :ai_features],
          description: 'Checkpoint of the event.'

        field :metadata, Types::JsonStringType,
          scopes: [:api, :read_api, :ai_features],
          description: 'Metadata associated with the event.'

        field :workflow_status, Types::Ai::DuoWorkflows::WorkflowStatusEnum,
          scopes: [:api, :read_api, :ai_features],
          description: 'Status of the workflow.'

        field :timestamp,
          Types::TimeType,
          scopes: [:api, :read_api, :ai_features],
          description: 'Time of the event.'

        field :parent_timestamp,
          Types::TimeType,
          scopes: [:api, :read_api, :ai_features],
          description: 'Time of the parent event.'

        field :errors, [GraphQL::Types::String],
          null: true,
          scopes: [:api, :read_api, :ai_features],
          description: 'Message errors.'
      end
    end
  end
end
