# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoWorkflows
      class WorkflowsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type Types::Ai::DuoWorkflows::WorkflowType, null: false

        argument :project_path, GraphQL::Types::ID,
          required: false,
          description: 'Full path of the project that contains the flows.'

        argument :type, GraphQL::Types::String,
          required: false,
          description: 'Type of flow to filter by (for example, software_development).'

        argument :exclude_types, [GraphQL::Types::String],
          required: false,
          description: 'Types of flows to exclude (for example, ["software_development", "chat"]).'

        argument :sort, Types::Ai::DuoWorkflows::WorkflowSortEnum,
          description: 'Sort flows by the criteria.',
          required: false,
          default_value: :created_desc

        argument :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          description: 'Environment, for example, IDE or web.',
          required: false

        argument :workflow_id, Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: false,
          description: 'Flow ID to filter by.'

        argument :search, GraphQL::Types::String,
          required: false,
          description: 'Flow title or goal to search for.'

        argument :status_group, Types::Ai::DuoWorkflows::WorkflowStatusGroupEnum,
          required: false,
          description: 'Status group to filter flow sessions by.'

        def resolve(**args)
          return [] unless current_user

          # Return empty array if type and exclude filters conflict
          return [] if conflicting_type_filters?(args)

          return resolve_single_workflow(args[:workflow_id]) if args[:workflow_id].present?

          ::Ai::DuoWorkflows::WorkflowsFinder.new(
            source: object,
            current_user: current_user,
            project_path: args[:project_path],
            type: args[:type],
            exclude_types: args[:exclude_types],
            environment: args[:environment],
            sort: args[:sort],
            search: args[:search],
            status_group: args[:status_group]
          ).results
        end

        private

        def conflicting_type_filters?(args)
          exclude_types = args[:exclude_types] || []
          return false unless args[:type].present? && exclude_types.present?

          exclude_types.include?(args[:type])
        end

        def resolve_single_workflow(workflow_id)
          Gitlab::Graphql::Lazy.with_value(find_object(id: workflow_id)) do |workflow|
            if workflow.nil?
              raise_resource_not_available_error! "Workflow not found"
            elsif !Ability.allowed?(current_user, :read_duo_workflow, workflow)
              raise_resource_not_available_error! "You don't have permission to access this workflow"
            else
              ::Ai::DuoWorkflows::Workflow.id_in([workflow.id])
            end
          end
        end

        def find_object(id:)
          GitlabSchema.find_by_gid(id)
        end
      end
    end
  end
end
