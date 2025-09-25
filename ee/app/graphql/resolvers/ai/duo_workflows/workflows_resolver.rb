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

        argument :sort, Types::SortEnum,
          description: 'Sort flows by the criteria.',
          required: false,
          default_value: :created_desc

        argument :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          description: 'Environment, for example, IDE or web.',
          required: false

        argument :workflow_id, Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: false,
          description: 'Flow ID to filter by.'

        def resolve(**args)
          return [] unless current_user

          # Return empty array if type and exclude filters conflict
          return [] if conflicting_type_filters?(args)

          return resolve_single_workflow(args[:workflow_id]) if args[:workflow_id].present?

          workflows = build_workflows_query(args)
          apply_filters(workflows, args)
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

        def build_workflows_query(args)
          workflows = ::Ai::DuoWorkflows::Workflow

          if object.is_a?(::Project)
            return [] unless current_user.can?(:duo_workflow, object)

            workflows.for_project(object).from_pipeline
          else
            workflows = workflows.for_user(current_user.id)
            apply_project_filter(workflows, args[:project_path])
          end
        end

        def apply_project_filter(workflows, project_path)
          return workflows unless project_path.present?

          project = Project.find_by_full_path(project_path)
          return [] unless current_user.can?(:duo_workflow, project)

          workflows.for_project(project)
        end

        def apply_filters(workflows, args)
          return workflows if workflows.empty?

          workflows = workflows.with_workflow_definition(args[:type]) if args[:type].present?
          workflows = workflows.without_workflow_definition(args[:exclude_types]) if args[:exclude_types].present?
          workflows = workflows.with_environment(args[:environment]) if args[:environment].present?

          workflows.order_by(args[:sort])
        end

        def find_object(id:)
          GitlabSchema.find_by_gid(id)
        end
      end
    end
  end
end
