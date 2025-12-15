# frozen_string_literal: true

module Types
  module Analytics
    module CustomDashboards
      class DashboardType < BaseObject
        graphql_name "CustomDashboard"

        authorize :read_custom_dashboard

        description "Customizable analytics dashboard"

        field :id,
          GlobalIDType[::Analytics::CustomDashboards::Dashboard],
          null: false,
          description: "Global ID of the custom dashboard."

        field :name,
          GraphQL::Types::String,
          null: false,
          description: "Display name of the dashboard."

        field :description,
          GraphQL::Types::String,
          null: true,
          description: "Optional summary or purpose of the dashboard."

        # rubocop:disable Graphql/JSONType -- We have JSON schema validation that enforces structure
        field :config,
          GraphQL::Types::JSON,
          null: false,
          description: "Dashboard layout and widget configuration."
        # rubocop:enable Graphql/JSONType

        field :organization,
          Types::Organizations::OrganizationType,
          null: false,
          description: "Organization that owns the dashboard."

        field :namespace,
          Types::NamespaceType,
          null: true,
          description: "Namespace scope of the dashboard, if any."

        field :project,
          Types::ProjectType,
          null: true,
          description: "Project scope of the dashboard, if any."

        # rubocop:disable GraphQL/ExtractType -- Dashboard ownership tracking, not standard audit metadata
        field :created_by,
          Types::UserType,
          null: false,
          description: "User who created the dashboard."

        field :created_at,
          Types::TimeType,
          null: false,
          description: "Timestamp when the dashboard was created."
        # rubocop:enable GraphQL/ExtractType

        field :lock_version,
          GraphQL::Types::Int,
          null: false,
          description: "Version used for optimistic concurrency control."

        # rubocop:disable GraphQL/ExtractType -- Dashboard ownership tracking, not standard audit metadata
        field :updated_by,
          Types::UserType,
          null: true,
          description: "User who last updated the dashboard."

        field :updated_at,
          Types::TimeType,
          null: false,
          description: "Timestamp when the dashboard was last updated."
        # rubocop:enable GraphQL/ExtractType
      end
    end
  end
end
