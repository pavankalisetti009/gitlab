# frozen_string_literal: true

module Mutations
  module WorkItems
    module Types
      class Update < BaseMutation
        graphql_name 'WorkItemTypeUpdate'

        include Mutations::ResolvesGroup
        include Gitlab::Utils::StrongMemoize

        # TODO: Add the auth and license check after this MR is merged:
        # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/221664
        # authorize :update_work_item_type

        field :work_item_type, ::Types::WorkItems::TypeType,
          null: true,
          description: 'Work item type that was updated.'

        argument :id, ::Types::GlobalIDType[::WorkItems::Type],
          required: true,
          description: 'Global ID of the work item type to update.'

        argument :name, GraphQL::Types::String,
          required: false,
          description: 'New name for the work item type.'

        argument :icon_name, GraphQL::Types::String,
          required: false,
          description: 'New icon name for the work item type.'

        argument :archive, GraphQL::Types::Boolean,
          required: false,
          default_value: false,
          description: 'Whether to archive the work item type.'

        argument :full_path, GraphQL::Types::String,
          required: false,
          description: 'Full path of the root group.'

        def resolve(full_path: nil, **args)
          namespace = full_path.present? ? resolve_group(full_path: full_path) : context[:current_organization]

          response = ::WorkItems::Types::UpdateService.new(
            container: namespace,
            current_user: current_user,
            params: args
          ).execute

          if response.success?
            response_object = response.payload[:work_item_type]
            context[:resource_parent] = response.payload[:resource_parent]
          end

          response_errors = response.error? ? Array(response.errors) : []

          {
            work_item_type: response_object,
            errors: response_errors
          }
        end
      end
    end
  end
end
