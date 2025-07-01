# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoWorkflows
      class WorkflowsResolver < BaseResolver
        type Types::Ai::DuoWorkflows::WorkflowType, null: false

        argument :project_path, GraphQL::Types::ID,
          required: false,
          description: 'Full path of the project containing the workflows.'

        argument :type, GraphQL::Types::String,
          required: false,
          description: 'Type of workflow to filter by (e.g., software_development).'

        argument :sort, Types::SortEnum,
          description: 'Sort workflows by the criteria.',
          required: false,
          default_value: :created_desc

        argument :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          description: 'Environment, e.g., ide or web.',
          required: false

        def resolve(**args)
          return [] unless current_user

          workflows = ::Ai::DuoWorkflows::Workflow.for_user(current_user.id)

          if args[:project_path].present?
            project = Project.find_by_full_path(args[:project_path])
            workflows = workflows.for_project(project)
          end

          workflows = workflows.with_workflow_definition(args[:type]) if args[:type].present?
          workflows = workflows.with_environment(args[:environment]) if args[:environment].present?

          workflows.order_by(args[:sort])
        end
      end
    end
  end
end
