# frozen_string_literal: true

module Mutations
  module Analytics
    module CustomDashboards
      class Create < BaseMutation
        graphql_name 'CreateCustomDashboard'
        description "Creates a custom dashboard in an organization."

        include Gitlab::Graphql::Authorize::AuthorizeResource

        authorize :create_custom_dashboard

        argument :organization_id,
          ::Types::GlobalIDType[::Organizations::Organization],
          required: true,
          description: "Organization the dashboard belongs to."

        argument :name, GraphQL::Types::String,
          required: true,
          description: "Dashboard name."

        argument :description, GraphQL::Types::String,
          required: false,
          description: "Dashboard description."

        # rubocop:todo Graphql/JSONType -- Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/581090
        argument :config, GraphQL::Types::JSON,
          required: true,
          description: "Dashboard layout/config JSON."
        # rubocop:enable Graphql/JSONType

        argument :namespace_id, ::Types::GlobalIDType[::Namespace],
          required: false,
          description: "Namespace to scope the dashboard to."

        field :dashboard, ::Types::Analytics::CustomDashboards::DashboardType,
          null: true,
          description: "Newly created dashboard."

        field :errors, [GraphQL::Types::String],
          null: false,
          description: "Errors encountered during creation."

        def resolve(organization_id:, namespace_id: nil, **attributes)
          organization = authorized_find!(id: organization_id)

          params = attributes.merge(
            namespace_id: parse_gid(namespace_id)
          ).compact

          response = ::Analytics::CustomDashboards::CreateService
            .new(current_user: current_user, organization: organization, params: params)
            .execute

          if response.success?
            { dashboard: response.payload[:dashboard], errors: [] }
          else
            { dashboard: nil, errors: Array(response.message) }
          end
        end

        private

        def find_object(id:)
          GitlabSchema.object_from_id(id, expected_type: ::Organizations::Organization)
        end

        def parse_gid(gid)
          return unless gid

          GlobalID::Locator.locate(gid)&.id
        rescue ActiveRecord::RecordNotFound
          nil
        end
      end
    end
  end
end
