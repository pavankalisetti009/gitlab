# frozen_string_literal: true

module Mutations
  module Ai
    module DuoWorkflows
      class Create < BaseMutation
        graphql_name 'AiDuoWorkflowCreate'

        # Auth is checked in allowed? depending on the container type
        # Further checks are performed by CreateWorkflowService based on the workflow definition

        def self.authorization_scopes
          super + [:ai_features]
        end

        argument :project_id, ::Types::GlobalIDType[::Project],
          required: false,
          description: "Global ID of the project the user is acting on."

        argument :namespace_id, ::Types::GlobalIDType[::Namespace],
          required: false,
          description: "Global ID of the namespace the user is acting on."

        argument :goal, GraphQL::Types::String,
          required: false,
          description: 'Goal of the workflow.'

        argument :agent_privileges, [GraphQL::Types::Int],
          required: false,
          description: 'Actions the agent is allowed to perform.'

        argument :pre_approved_agent_privileges, [GraphQL::Types::Int],
          required: false,
          description: 'Actions the agent can perform without asking for approval.'

        argument :workflow_definition, GraphQL::Types::String,
          required: false,
          description: 'Workflow type based on its capability.'

        argument :allow_agent_to_request_user, GraphQL::Types::Boolean,
          required: false,
          description: 'When enabled, Duo Agent Platform may stop to ask the user questions before proceeding.'

        argument :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          required: false,
          description: 'Environment for the workflow.'

        argument :ai_catalog_item_version_id, ::Types::GlobalIDType[::Ai::Catalog::ItemVersion],
          required: false,
          description: 'ID of the catalog item the workflow is triggered from.'

        field :workflow, Types::Ai::DuoWorkflows::WorkflowType,
          null: true,
          description: 'Created workflow.'

        field :errors, [GraphQL::Types::String],
          null: false,
          description: 'Errors encountered during the creation process.'

        def resolve(**args)
          container = if args[:project_id]
                        GitlabSchema.find_by_gid(args[:project_id]).sync
                      elsif args[:namespace_id]
                        GitlabSchema.find_by_gid(args[:namespace_id]).sync
                      else
                        current_user.user_preference.get_default_duo_namespace
                      end

          item_version = GitlabSchema.find_by_gid(args[:ai_catalog_item_version_id])&.sync

          raise_resource_not_available_error! unless allowed?(container)

          raise_resource_not_available_error! 'User is not authorized to use agent catalog item.' unless
            item_version.nil? || Ability.allowed?(current_user, :read_ai_catalog_item, item_version)

          workflow_params = {
            goal: args[:goal],
            agent_privileges: args[:agent_privileges],
            pre_approved_agent_privileges: args[:pre_approved_agent_privileges],
            workflow_definition: args[:workflow_definition],
            allow_agent_to_request_user: args[:allow_agent_to_request_user],
            environment: args[:environment],
            ai_catalog_item_version_id: item_version&.id
          }.compact

          service = ::Ai::DuoWorkflows::CreateWorkflowService.new(
            container: container,
            current_user: current_user,
            params: workflow_params
          )

          result = service.execute

          raise_resource_not_available_error!(result.message) if result.error? && result.http_status == :forbidden
          return { errors: [result[:message]], workflow: nil } if result[:status] == :error

          {
            workflow: result[:workflow],
            errors: errors_on_object(result[:workflow])
          }
        end

        private

        def allowed?(container)
          return Ability.allowed?(current_user, :read_project, container) if container.is_a?(Project)

          Ability.allowed?(current_user, :read_group, container)
        end
      end
    end
  end
end
