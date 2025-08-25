# frozen_string_literal: true

module Search
  module Zoekt
    class CodeQueryBuilder < QueryBuilder
      def build
        { query: build_payload }
      end

      private

      def build_payload
        auth = Search::AuthorizationContext.new(current_user)

        base_query = Filters.by_query_string(query)
        return build_repo_ids_payload(base_query) unless use_zoekt_traversal_id_query?

        children = [base_query, Filters.or_filters(*access_branches(auth))]

        children << Filters.by_archived(false) unless filters[:include_archived] == true
        children << Filters.by_forked(false) if filters[:exclude_forks] == true

        case options.fetch(:search_level)
        when :project
          raise ArgumentError, 'Project ID cannot be empty for project search' if project_id.blank?

          children << by_repo_ids([project_id], context: { name: 'project_id_search' })
        when :group
          children << Filters.by_traversal_ids(
            auth.get_traversal_ids_for_group(group_id),
            context: { name: 'traversal_ids_for_group' }
          )
        when :global
          # no additional filters needed
        else
          raise ArgumentError, "Unsupported search level for zoekt search: #{options.fetch(:search_level)}"
        end

        Filters.and_filters(*children)
      end

      def build_repo_ids_payload(base_query)
        raise ArgumentError, 'Repo ids cannot be empty' if options[:repo_ids].blank?

        Filters.and_filters(base_query, by_repo_ids(options[:repo_ids]))
      end

      def access_branches(auth)
        @access_branches ||= AccessBranchBuilder.new(current_user, auth, options).build
      end

      def by_repo_ids(ids, context: nil)
        return Filters.by_project_ids(ids, context: context) if use_meta_project_ids?

        Filters.by_repo_ids(ids, context: context)
      end

      def use_zoekt_traversal_id_query?
        ::Search::Zoekt.use_traversal_id_queries?(current_user)
      end

      def use_meta_project_ids?
        Feature.enabled?(:zoekt_search_meta_project_ids, current_user)
      end
    end
  end
end
