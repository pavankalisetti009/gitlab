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

          def by_project_confidentiality(query_hash:, options:)
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
