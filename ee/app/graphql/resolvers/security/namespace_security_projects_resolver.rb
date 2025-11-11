# frozen_string_literal: true

module Resolvers
  module Security
    class NamespaceSecurityProjectsResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      MAX_ATTRIBUTE_FILTERS = 20

      argument :namespace_id, Types::GlobalIDType[::Namespace],
        required: true,
        description: 'Global ID of the namespace.'

      argument :search, GraphQL::Types::String,
        required: false,
        description: 'Search projects by name.'

      argument :vulnerability_count_filters, [Types::Security::VulnerabilityCountFilterInputType],
        required: false,
        description: 'Filter projects by vulnerability counts using comparison operators.'

      argument :security_analyzer_filters, [Types::Security::AnalyzerFilterInputType],
        required: false,
        description: 'Filter projects by analyzer type and status.'

      argument :attribute_filters, [Types::Security::AttributeFilterInputType],
        required: false,
        validates: { length: { maximum: MAX_ATTRIBUTE_FILTERS } },
        description: "Filter projects by security attributes. Up to #{MAX_ATTRIBUTE_FILTERS} items."

      argument :include_subgroups, GraphQL::Types::Boolean,
        required: false,
        default_value: false,
        description: 'Include also subgroup projects.'

      type Types::ProjectType.connection_type, null: true
      authorize :read_security_inventory

      alias_method :group, :object

      def resolve(**args)
        # This resolver filters projects-related records from the sec_db, then loads the projects based on the
        # project_ids returned from that paginated list of ids.
        namespace = authorized_find!(id: args[:namespace_id])
        security_result = fetch_paginated_security_data(args, namespace)
        return Project.none if security_result[:ids].empty?

        projects = fetch_projects_by_ids(security_result[:ids], namespace, args)
        create_cross_db_connection(projects, security_result)
      end

      private

      def fetch_paginated_security_data(params, namespace)
        ::Security::InventoryFilters::ProjectsFinderService.new(
          namespace: namespace,
          params: params
        ).execute
      end

      def fetch_projects_by_ids(ids, namespace, args)
        finder_params = { include_subgroups: args[:include_subgroups], include_archived: false, ids: ids }

        ::Namespaces::ProjectsFinder.new(
          namespace: namespace,
          current_user: current_user,
          params: finder_params
        ).execute
      end

      def create_cross_db_connection(projects, security_result)
        page_info = security_result[:page_info]

        paginated_array = ::Gitlab::Graphql::ExternallyPaginatedArray.new(
          page_info[:start_cursor],
          page_info[:end_cursor],
          *projects.to_a,
          has_next_page: page_info[:has_next_page],
          has_previous_page: page_info[:has_previous_page]
        )

        ::Gitlab::Graphql::Pagination::ExternallyPaginatedArrayConnection.new(
          paginated_array,
          context: context,
          max_page_size: context.schema.default_max_page_size
        )
      end
    end
  end
end
