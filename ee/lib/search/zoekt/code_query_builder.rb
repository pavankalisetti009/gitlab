# frozen_string_literal: true

module Search
  module Zoekt
    class CodeQueryBuilder < QueryBuilder
      REPO_ENABLED = ::Featurable::ENABLED # 20
      REPO_PRIVATE = ::Featurable::PRIVATE # 10
      VIS_PUBLIC = ::Gitlab::VisibilityLevel::PUBLIC # 20
      VIS_INTERNAL = ::Gitlab::VisibilityLevel::INTERNAL # 10

      def build
        { query: build_payload }
      end

      private

      def build_payload
        base_query = Filters.by_query_string(query)
        return build_repo_ids_payload(base_query) unless use_zoekt_traversal_id_query?

        children = [base_query, Filters.or_filters(*access_branches)]

        children << Filters.by_archived(false) unless filters[:include_archived] == true
        children << Filters.by_forked(false) if filters[:exclude_forks] == true

        case options.fetch(:search_level)
        when :project
          raise ArgumentError, 'Project ID cannot be empty for project search' if project_id.blank?

          children << by_repo_ids([project_id])
        when :group
          children << Filters.by_traversal_ids(auth.get_traversal_ids_for_group(group_id))
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

      def access_branches
        @access_branches ||= build_access_branches
      end

      def build_access_branches
        return [admin_branch] if current_user&.can_read_all_resources?
        return [public_branch] if current_user.blank?

        private_branch_filters = []
        if authorized_traversal_ids.present?
          private_branch_filters.concat authorized_traversal_ids.map { |t|
            Filters.by_traversal_ids(t)
          }
        end

        private_branch_filters << by_repo_ids(authorized_project_ids) if authorized_project_ids.present?

        return [public_branch, internal_branch] if private_branch_filters.empty?

        [public_branch, internal_branch, private_branch(private_branch_filters)]
      end

      def admin_branch
        Filters.or_filters(
          Filters.by_meta(key: 'repository_access_level', value: REPO_PRIVATE),
          Filters.by_meta(key: 'repository_access_level', value: REPO_ENABLED)
        )
      end

      def public_branch
        Filters.and_filters(
          Filters.by_meta(key: 'repository_access_level', value: REPO_ENABLED),
          Filters.by_meta(key: 'visibility_level', value: VIS_PUBLIC)
        )
      end

      def internal_branch
        Filters.and_filters(
          Filters.by_meta(key: 'visibility_level', value: VIS_INTERNAL),
          Filters.by_meta(key: 'repository_access_level', value: REPO_ENABLED)
        )
      end

      def private_branch(filters)
        Filters.and_filters(
          admin_branch,
          Filters.or_filters(*filters)
        )
      end

      def by_repo_ids(ids)
        return Filters.by_project_ids(ids) if use_meta_project_ids?

        Filters.by_repo_ids(ids)
      end

      def use_zoekt_traversal_id_query?
        Feature.enabled?(:zoekt_traversal_id_queries, current_user)
      end

      def use_meta_project_ids?
        Feature.enabled?(:zoekt_search_meta_project_ids, current_user)
      end
    end
  end
end
