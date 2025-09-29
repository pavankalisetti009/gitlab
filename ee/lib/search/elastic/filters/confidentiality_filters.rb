# frozen_string_literal: true

module Search
  module Elastic
    module Filters
      module ConfidentialityFilters
        extend ActiveSupport::Concern

        class_methods do
          include ::Elastic::Latest::QueryContext::Aware
          include Search::Elastic::Concerns::FilterUtils
          include Search::Elastic::Concerns::AuthorizationUtils

          def by_combined_confidentiality(query_hash:, options:)
            combined_filter = Search::Elastic::BoolExpr.new

            if options[:use_project_authorization]
              add_filter(combined_filter, :should) do
                project_filter = Search::Elastic::BoolExpr.new
                project_options = options.dup
                project_options[:filter_path] = [:filter]

                by_project_confidentiality(query_hash: project_filter, options: project_options)

                project_filter.to_bool_query
              end
            end

            if options[:use_group_authorization]
              add_filter(combined_filter, :should) do
                group_filter = Search::Elastic::BoolExpr.new
                group_options = options.dup
                group_options[:filter_path] = [:filter]
                # group authorization for confidentiality uses min_access_level
                # `features` is only needed for the project confidentiality so remove it for group checks
                group_options.delete(:features)

                by_group_level_confidentiality(query_hash: group_filter, options: group_options)

                group_filter.to_bool_query
              end
            end

            add_filter(query_hash, :query, :bool, :filter) do
              combined_filter.to_bool_query
            end
          end

          # Applies confidentiality filters for project-level resources.
          #
          # This method constructs an Elasticsearch query to filter project-level resources
          # based on their confidentiality status and the current user's access permissions.
          # It supports both legacy and new (traversal IDs based) filtering mechanisms.
          #
          # @param query_hash [Hash] The Elasticsearch query hash to which filters will be added.
          # @param options [Hash] A hash of options controlling the filtering behavior.
          # @option options [Boolean] :confidential (nil) If `true`, only confidential resources are returned.
          #   If `false`, only non-confidential resources are returned. If `nil`, both are considered,
          #   and access rules are applied.
          # @option options [User] :current_user The user for whom the confidentiality filters are applied.
          #   If `nil`, only public non-confidential resources are accessible.
          # @option options [Array<Integer>] :project_ids (nil) An array of project IDs to scope the search.
          # @option options [Array<Integer>] :group_ids (nil) An array of group IDs to scope the search.
          # @option options [Array<Symbol>] :filter_path ([:query, :bool, :filter]) The path within the
          #   `query_hash` where the generated filter should be inserted.
          # @option options [Integer] :min_access_level_confidential The minimum access level required
          #   to view confidential resources. Defaults to `Gitlab::Access::PLANNER`.
          # @option options [String] :project_id_field ('project_id') The field name in Elasticsearch
          #   documents that stores the project ID.
          # @option options [String] :traversal_ids_prefix ('traversal_ids') The field name prefix in
          #   Elasticsearch documents that stores traversal IDs for ancestry.
          #
          # @return [Hash] The modified `query_hash` with confidentiality filters applied.
          #
          # @note This method uses the `search_project_confidentiality_use_traversal_ids` feature flag
          #   to switch between legacy and traversal ID-based filtering.
          def by_project_confidentiality(query_hash:, options:)
            if ::Feature.disabled?(:search_project_confidentiality_use_traversal_ids, options[:current_user])
              return legacy_project_confidentiality_filter(query_hash:, options:)
            end

            confidential = options[:confidential]
            user = options[:current_user]
            filter_path = options.fetch(:filter_path, [:query, :bool, :filter])

            context.name(:filters, :confidentiality, :projects) do
              apply_user_confidentiality_filter(query_hash, user, confidential, filter_path)

              next query_hash if user&.can_read_all_resources?
              next query_hash if confidential == false

              apply_confidentiality_access_filters(query_hash, user, confidential, filter_path, options)
            end
          end

          def by_group_level_confidentiality(query_hash:, options:)
            confidential = options[:confidential]
            user = options[:current_user]
            filter_path = options.fetch(:filter_path, [:query, :bool, :filter])

            context.name(:filters, :confidentiality, :groups) do
              if [true, false].include?(confidential)
                add_filter(query_hash, *filter_path) do
                  { term: { confidential: { _name: context.name(:user_filter), value: confidential } } }
                end
              end

              next query_hash if user&.can_read_all_resources?

              filter = Search::Elastic::BoolExpr.new
              filter.minimum_should_match = 1

              # anonymous user, public groups, non-confidential
              add_filter(filter, :should) do
                non_confidential_filter_for_public_groups
              end

              if user && !user.external?
                # logged in user, public groups, non-confidential
                add_filter(filter, :should) do
                  non_confidential_filter_for_internal_groups
                end
              end

              if user
                # logged in user, private groups, non-confidential
                add_filter(filter, :should) do
                  non_confidential_filter_for_private_groups(user, options)
                end

                # logged-in user, private projects ancestor hierarchy, non-confidential
                add_filter(filter, :should) do
                  non_confidential_filter_for_authorized_project_ancestors(user)
                end

                # logged in user, private groups, confidential
                add_filter(filter, :should) do
                  confidential_filter_for_private_groups(user, options)
                end
              end

              add_filter(query_hash, *filter_path) do
                filter.to_bool_query
              end
            end
          end

          private

          def apply_user_confidentiality_filter(query_hash, user, confidential, filter_path)
            return query_hash unless [true, false].include?(confidential)

            if !user && confidential == true
              add_filter(query_hash, *filter_path) do
                { match_none: { _name: context.name(:anonymous_user_confidential_filter_not_allowed) } }
              end

              return
            end

            add_filter(query_hash, *filter_path) do
              { term: { confidential: { _name: context.name(:user_filter), value: confidential } } }
            end
          end

          def apply_confidentiality_access_filters(query_hash, user, confidential, filter_path, options)
            # anonymous users can only see non-confidential data
            unless user
              add_filter(query_hash, *filter_path) do
                non_confidential_filter
              end

              return query_hash
            end

            if confidential == true
              # reduce query nesting when confidential filter is selected
              add_filter(query_hash, *filter_path) do
                build_confidential_access_filter(user, options, confidential)
              end
            else
              bool_expr = ::Search::Elastic::BoolExpr.new

              # reduce query complexity if confidential user filter is selected
              add_filter(bool_expr, :should) do
                non_confidential_filter
              end

              add_filter(bool_expr, :should) do
                build_confidential_access_filter(user, options, confidential)
              end

              add_filter(query_hash, *filter_path) do
                bool_expr.to_bool_query
              end
            end

            query_hash
          end

          def build_confidential_access_filter(user, options, confidential)
            confidential_filter = ::Search::Elastic::BoolExpr.new
            min_access_level = options.fetch(:min_access_level_confidential)

            traversal_ids = traversal_ids_for_user(user, options.merge(min_access_level: min_access_level))
            projects = projects_for_user(user, options)
              .where_exists(user.authorizations_for_projects(min_access_level: min_access_level))

            add_filter(confidential_filter, :filter) do
              next if confidential == true

              { term: { confidential: { _name: context.name(:confidential), value: true } } }
            end

            add_filter(confidential_filter, :should) do
              { term: { author_id: { _name: context.name(:confidential, :as_author), value: user.id } } }
            end

            # assignees can always see confidential issues
            add_filter(confidential_filter, :should) do
              { term: { assignee_id: { _name: context.name(:confidential, :as_assignee), value: user.id } } }
            end

            add_filter(confidential_filter, :should) do
              next if projects.empty?

              project_id_field = options.fetch(:project_id_field, PROJECT_ID_FIELD)
              {
                terms: {
                  _name: context.name(:project, :member),
                  "#{project_id_field}": projects.pluck_primary_key
                }
              }
            end

            add_filter(confidential_filter, :should) do
              next if traversal_ids.empty?

              traversal_id_field = options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)
              ancestry_filter(traversal_ids, traversal_id_field: traversal_id_field)
            end

            confidential_filter.to_bool_query
          end

          def legacy_project_confidentiality_filter(query_hash:, options:)
            confidential = options[:confidential]
            user = options[:current_user]
            project_ids = options[:project_ids]
            filter_path = options.fetch(:filter_path, [:query, :bool, :filter])

            context.name(:filters, :confidentiality, :projects) do
              if [true, false].include?(confidential)
                add_filter(query_hash, *filter_path) do
                  { term: { confidential: { _name: context.name(:user_filter), value: confidential } } }
                end
              end

              # There might be an option to not add confidentiality filter for project level search
              next query_hash if user&.can_read_all_resources?

              scoped_project_ids = scoped_project_ids(user, project_ids)
              authorized_project_ids = authorized_project_ids(user, scoped_project_ids)

              non_confidential_filter = {
                term: { confidential: { _name: context.name(:non_confidential), value: false } }
              }

              filter = if user
                         confidential_filter = {
                           bool: {
                             must: [
                               { term: { confidential: { _name: context.name(:confidential), value: true } } },
                               {
                                 bool: {
                                   should: [
                                     { term:
                                       { author_id: {
                                         _name: context.name(:confidential, :as_author),
                                         value: user.id
                                       } } },
                                     { term:
                                       { assignee_id: {
                                         _name: context.name(:confidential, :as_assignee),
                                         value: user.id
                                       } } },
                                     { terms: { _name: context.name(:confidential, :project, :membership, :id),
                                                project_id: authorized_project_ids } }
                                   ]
                                 }
                               }
                             ]
                           }
                         }

                         {
                           bool: {
                             should: [
                               non_confidential_filter,
                               confidential_filter
                             ]
                           }
                         }
                       else
                         non_confidential_filter
                       end

              add_filter(query_hash, *filter_path) do
                filter
              end
            end
          end

          def non_confidential_filter
            {
              term: { confidential: { _name: context.name(:non_confidential), value: false } }
            }
          end

          def non_confidential_filter_for_public_groups
            {
              bool: {
                _name: context.name(:non_confidential, :public),
                must: [
                  { term: { confidential: { value: false } } },
                  { term: { namespace_visibility_level: { value: ::Gitlab::VisibilityLevel::PUBLIC } } }
                ]
              }
            }
          end

          def non_confidential_filter_for_internal_groups
            {
              bool: {
                _name: context.name(:non_confidential, :internal),
                must: [
                  { term: { confidential: { value: false } } },
                  { term: { namespace_visibility_level: { value: ::Gitlab::VisibilityLevel::INTERNAL } } }
                ]
              }
            }
          end

          def non_confidential_filter_for_private_groups(user, options)
            min_access_for_non_confidential = options[:min_access_level_non_confidential]
            non_confidential_options = options.merge(min_access_level: min_access_for_non_confidential)
            traversal_ids = traversal_ids_for_user(user, non_confidential_options)
            return if traversal_ids.empty?

            traversal_ids_prefix = options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)
            context.name(:non_confidential, :private) do
              {
                bool: {
                  _name: context.name,
                  must: [
                    { term: { confidential: { value: false } } }
                  ],
                  should: ancestry_filter(traversal_ids, traversal_id_field: traversal_ids_prefix),
                  minimum_should_match: 1
                }
              }
            end
          end

          def non_confidential_filter_for_authorized_project_ancestors(user)
            authorized_project_ancestry_namespace_ids = authorized_namespace_ids_for_project_group_ancestry(user)
            return if authorized_project_ancestry_namespace_ids.empty?

            context.name(:non_confidential, :private) do
              {
                bool: {
                  _name: context.name,
                  must: [
                    { term: { confidential: { value: false } } },
                    { terms: {
                      _name: context.name(:project, :membership),
                      namespace_id: authorized_project_ancestry_namespace_ids
                    } }
                  ]
                }
              }
            end
          end

          def confidential_filter_for_private_groups(user, options)
            min_access_for_confidential = options[:min_access_level_confidential]
            confidential_options = options.merge(min_access_level: min_access_for_confidential)
            traversal_ids = traversal_ids_for_user(user, confidential_options)

            return if traversal_ids.empty?

            traversal_ids_prefix = options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)
            context.name(:confidential, :private) do
              {
                bool: {
                  _name: context.name,
                  must: [
                    { term: { confidential: { value: true } } }
                  ],
                  should: ancestry_filter(traversal_ids, traversal_id_field: traversal_ids_prefix),
                  minimum_should_match: 1
                }
              }
            end
          end

          def authorized_project_ids(current_user, scoped_project_ids)
            return [] unless current_user

            authorized_project_ids = current_user.authorized_projects(Gitlab::Access::REPORTER).pluck_primary_key.to_set

            # if the current search is limited to a subset of projects, we should do
            # confidentiality check for these projects.
            authorized_project_ids &= scoped_project_ids.to_set unless scoped_project_ids == :any

            authorized_project_ids.to_a
          end
        end
      end
    end
  end
end
