# frozen_string_literal: true

module Search
  module Elastic
    module Filters
      class << self
        include ::Elastic::Latest::QueryContext::Aware

        def by_source_branch(query_hash:, options:)
          source_branch = options[:source_branch]
          not_source_branch = options[:not_source_branch]

          return query_hash unless source_branch || not_source_branch

          context.name(:filters) do
            should = []
            if source_branch
              should << { term: { source_branch: { _name: context.name(:source_branch), value: source_branch } } }
            end

            if not_source_branch
              should << {
                bool: {
                  must_not: {
                    term: { source_branch: { _name: context.name(:not_source_branch), value: not_source_branch } }
                  }
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should, minimum_should_match: 1 } }
            end
          end
        end

        def by_target_branch(query_hash:, options:)
          target_branch = options[:target_branch]
          not_target_branch = options[:not_target_branch]

          return query_hash unless target_branch || not_target_branch

          context.name(:filters) do
            should = []
            if target_branch
              should << { term: { target_branch: { _name: context.name(:target_branch), value: target_branch } } }
            end

            if not_target_branch
              should << {
                bool: {
                  must_not: {
                    term: { target_branch: { _name: context.name(:not_target_branch), value: not_target_branch } }
                  }
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should, minimum_should_match: 1 } }
            end
          end
        end

        def by_author(query_hash:, options:)
          author_username = options[:author_username]
          not_author_username = options[:not_author_username]

          return query_hash unless author_username || not_author_username

          included_user = User.find_by_username(author_username)
          excluded_user = User.find_by_username(not_author_username)

          return query_hash unless included_user || excluded_user

          context.name(:filters) do
            should = []
            if included_user
              should << { term: { author_id: { _name: context.name(:author), value: included_user.id } } }
            end

            if excluded_user
              should << {
                bool: {
                  must_not: {
                    term: { author_id: { _name: context.name(:not_author), value: excluded_user.id } }
                  }
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should, minimum_should_match: 1 } }
            end
          end
        end

        def by_work_item_type_ids(query_hash:, options:)
          work_item_type_ids = options[:work_item_type_ids]
          not_work_item_type_ids = options[:not_work_item_type_ids]

          return query_hash unless work_item_type_ids || not_work_item_type_ids

          context.name(:filters) do
            if work_item_type_ids
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must: {
                      terms: {
                        _name: context.name(:work_item_type_ids),
                        work_item_type_id: work_item_type_ids
                      }
                    }
                  }
                }
              end
            end

            if not_work_item_type_ids
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must_not: {
                      terms: {
                        _name: context.name(:not_work_item_type_ids),
                        work_item_type_id: not_work_item_type_ids
                      }
                    }
                  }
                }
              end
            end
          end
          query_hash
        end

        def by_not_hidden(query_hash:, options:)
          user = options[:current_user]
          return query_hash if user&.can_admin_all_resources?

          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              { term: { hidden: { _name: context.name(:not_hidden), value: false } } }
            end
          end
        end

        def by_state(query_hash:, options:)
          state = options[:state]
          return query_hash if state.blank? || state == 'all'
          return query_hash unless API::Helpers::SearchHelpers.search_states.include?(state)

          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              { match: { state: { _name: context.name(:state), query: state } } }
            end
          end
        end

        def by_archived(query_hash:, options:)
          raise ArgumentError, 'search_level is a required option' unless options.key?(:search_level)

          include_archived = !!options[:include_archived]
          search_level = options[:search_level].to_sym
          return query_hash if search_level == :project
          return query_hash if include_archived

          context.name(:filters) do
            archived_false_filter = { bool: { filter: { term: { archived: { value: false } } } } }
            archived_missing_filter = { bool: { must_not: { exists: { field: 'archived' } } } }
            exclude_archived_filter = { bool: { _name: context.name(:non_archived),
                                                should: [archived_false_filter, archived_missing_filter] } }

            add_filter(query_hash, :query, :bool, :filter) do
              exclude_archived_filter
            end
          end
        end

        # uses `label_name` if provided, falls back to `labels`
        def by_label_ids(query_hash:, options:)
          return query_hash if options[:count_only] || options[:aggregation]

          return query_hash unless [options[:label_name], options[:labels]].flatten.any?

          if options[:label_name]
            label_names_hash = find_labels_by_name([options[:label_name]].flatten, options)
            return query_hash unless label_names_hash.any?

            must_query = { must: [] }
            context.name(:filters) do
              label_names_hash.each_value do |label_ids|
                must_query[:must] << {
                  terms: {
                    _name: context.name(:label_ids),
                    label_ids: label_ids
                  }
                }
              end
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: must_query }
            end
          else
            labels = [options[:labels]].flatten
            context.name(:filters) do
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  terms_set: {
                    label_ids: {
                      _name: context.name(:label_ids),
                      terms: labels,
                      minimum_should_match_script: {
                        source: 'params.num_terms'
                      }
                    }
                  }
                }
              end
            end
          end
        end

        def by_confidentiality(query_hash:, options:)
          confidential = options[:confidential]
          user = options[:current_user]
          project_ids = options[:project_ids]

          context.name(:filters) do
            if [true, false].include?(confidential)
              add_filter(query_hash, :query, :bool, :filter) do
                { term: { confidential: confidential } }
              end
            end

            next query_hash if user&.can_read_all_resources?

            scoped_project_ids = scoped_project_ids(user, project_ids)
            authorized_project_ids = authorized_project_ids(user, scoped_project_ids)

            # we can shortcut the filter if the user is authorized to see
            # all the projects for which this query is scoped on
            if !(scoped_project_ids == :any || scoped_project_ids.empty?) &&
                (authorized_project_ids.to_set == scoped_project_ids.to_set)
              next query_hash
            end

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

            add_filter(query_hash, :query, :bool, :filter) do
              filter
            end
          end
        end

        def by_authorization(query_hash:, options:)
          user = options[:current_user]
          project_ids = options[:project_ids]
          group_ids = options[:group_ids]
          use_traversal_ids = options.fetch(:authorization_use_traversal_ids)

          context.name(:filters) do
            if project_ids == :any || group_ids.blank? || !use_traversal_ids
              next project_ids_filter(query_hash, options)
            end

            namespaces = Namespace.find(authorized_namespace_ids(user, group_ids))

            next project_ids_filter(query_hash, options) if namespaces.blank?

            traversal_ids_filter(query_hash, namespaces, options)
          end
        end

        def by_type(query_hash:, options:)
          raise ArgumentError, 'by_type filter requires doc_type option' unless options.key?(:doc_type)

          doc_type = options[:doc_type]
          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              {
                term: {
                  type: {
                    _name: context.name(:doc, :is_a, doc_type),
                    value: doc_type
                  }
                }
              }
            end
          end
        end

        private

        # This is a helper method that we are using to add filter conditions
        # in this method we are skipping all blank hashes and we can use it for adding nested filter conditions.
        # `path` is a sequence of key objects (Hash#dig syntax). The value by that path should be an array.
        def add_filter(query_hash, *path)
          filter_result = yield

          return query_hash if filter_result.blank?

          query_hash.dig(*path) << filter_result
          query_hash
        end

        def scoped_project_ids(current_user, project_ids)
          return :any if project_ids == :any

          project_ids ||= []

          # When reading cross project is not allowed, only allow searching a
          # a single project, so the `:read_*` ability is only checked once.
          return [] if !Ability.allowed?(current_user, :read_cross_project) && project_ids.size > 1

          project_ids
        end

        def authorized_project_ids(current_user, scoped_project_ids)
          return [] unless current_user

          authorized_project_ids = current_user.authorized_projects(Gitlab::Access::REPORTER).pluck_primary_key.to_set

          # if the current search is limited to a subset of projects, we should do
          # confidentiality check for these projects.
          authorized_project_ids &= scoped_project_ids.to_set unless scoped_project_ids == :any

          authorized_project_ids.to_a
        end

        def authorized_namespace_ids(user, group_ids)
          return [] unless user && group_ids.present?

          authorized_ids = user.authorized_groups.pluck_primary_key.to_set
          authorized_ids.intersection(group_ids.to_set).to_a
        end

        # Builds an elasticsearch query that will select child documents from a
        # set of projects, taking user access rules into account.
        def project_ids_filter(query_hash, options)
          context.name(:project) do
            project_query = project_ids_query(options)

            add_filter(query_hash, :query, :bool, :filter) do
              # Some models have denormalized project permissions into the
              # document so that we do not need to use joins
              if options[:no_join_project]
                project_query[:_name] = context.name
                {
                  bool: project_query
                }
              else
                {
                  has_parent: {
                    _name: "#{context.name}:parent",
                    parent_type: "project",
                    query: {
                      bool: project_query
                    }
                  }
                }
              end
            end
          end
        end

        # Builds an elasticsearch query that will select projects the user is
        # granted access to.
        #
        # If a project feature(s) is specified, it indicates interest in child
        # documents gated by that project feature - e.g., "issues". The feature's
        # visibility level must be taken into account.
        def project_ids_query(options)
          user = options[:current_user]
          project_ids = options[:project_ids]
          public_and_internal_projects = options[:public_and_internal_projects]
          features = options[:features]
          no_join_project = options[:no_join_project]
          project_id_field = options[:project_id_field]
          project_visibility_level_field = options.fetch(:project_visibility_level_field, :visibility_level)

          scoped_project_ids = scoped_project_ids(user, project_ids)

          # At least one condition must be present, so pick no projects for
          # anonymous users.
          # Pick private, internal and public projects the user is a member of.
          # Pick all private projects for admins & auditors.
          conditions = pick_projects_by_membership(
            scoped_project_ids,
            user, no_join_project,
            features: features,
            project_id_field: project_id_field,
            project_visibility_level_field: project_visibility_level_field
          )

          if public_and_internal_projects
            context.name(:visibility) do
              # Skip internal projects for anonymous and external users.
              # Others are given access to all internal projects.
              #
              # Admins & auditors get access to internal projects even
              # if the feature is private.
              if user && !user.external?
                conditions += pick_projects_by_visibility(Project::INTERNAL, user, features,
                  project_visibility_level_field: project_visibility_level_field)
              end

              # All users, including anonymous, can access public projects.
              # Admins & auditors get access to public projects where the feature is
              # private.
              conditions += pick_projects_by_visibility(Project::PUBLIC, user, features,
                project_visibility_level_field: project_visibility_level_field)
            end
          end

          { should: conditions }
        end

        # Most users come with a list of projects they are members of, which may
        # be a mix of public, internal or private. Grant access to them all, as
        # long as the project feature is not disabled.
        #
        # Admins & auditors are given access to all private projects. Access to
        # internal or public projects where the project feature is private is not
        # granted here.
        def pick_projects_by_membership(
          project_ids, user, no_join_project, features: nil, project_id_field: nil,
          project_visibility_level_field: :visibility_level)
          # This method is used to construct a query on the join as well as query
          # on top level doc. When querying top level doc the project's ID is
          # used from project_id_field with the default value of `project_id`
          # When joining it is just `id`.
          id_field = if no_join_project
                       project_id_field || :project_id
                     else
                       :id
                     end

          if features.nil?
            if project_ids == :any
              return [{ term: { project_visibility_level_field => { _name: context.name(:any),
                                                                    value: Project::PRIVATE } } }]
            end

            return [{ terms: { _name: context.name(:membership, :id), id_field => project_ids } }]
          end

          Array(features).map do |feature|
            condition =
              if project_ids == :any
                { term: { project_visibility_level_field => { _name: context.name(:any), value: Project::PRIVATE } } }
              else
                {
                  terms: {
                    _name: context.name(:membership, :id),
                    id_field => filter_ids_by_feature(project_ids, user, feature)
                  }
                }
              end

            limit = {
              terms: {
                _name: context.name(feature, :enabled_or_private),
                "#{feature}_access_level" => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
              }
            }

            {
              bool: {
                filter: [condition, limit]
              }
            }
          end
        end

        # Grant access to projects of the specified visibility level to the user.
        #
        # If a project feature is specified, access is only granted if the feature
        # is enabled or, for admins & auditors, private.
        def pick_projects_by_visibility(visibility, user, features, project_visibility_level_field: :visibility_level)
          context.name(visibility) do
            condition = { term: { project_visibility_level_field => { _name: context.name, value: visibility } } }

            limit_by_feature(condition, features, include_members_only: user&.can_read_all_resources?)
          end
        end

        # If a project feature(s) is specified, access is dependent on its visibility
        # level being enabled (or private if `include_members_only: true`).
        #
        # This method is a no-op if no project feature is specified.
        # It accepts an array of features or a single feature, when an array is provided
        # it queries if any of the features is enabled.
        #
        # Always denies access to projects when the features are disabled - even to
        # admins & auditors - as stale child documents may be present.
        def limit_by_feature(condition, features, include_members_only:)
          return [condition] unless features

          features = Array(features)
          features.map do |feature|
            context.name(feature, :access_level) do
              limit =
                if include_members_only
                  {
                    terms: {
                      _name: context.name(:enabled_or_private),
                      "#{feature}_access_level" => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    }
                  }
                else
                  {
                    term: {
                      "#{feature}_access_level" => {
                        _name: context.name(:enabled),
                        value: ::ProjectFeature::ENABLED
                      }
                    }
                  }
                end

              {
                bool: {
                  _name: context.name,
                  filter: [condition, limit]
                }
              }
            end
          end
        end

        def traversal_ids_filter(query_hash, namespaces, options)
          namespace_ancestry = namespaces.map(&:elastic_namespace_ancestry)

          context.name(:reject_projects) do
            add_filter(query_hash, :query, :bool, :must_not) do
              rejected_project_filter(namespaces, options)
            end
          end

          traversal_ids_ancestry_filter(query_hash, namespace_ancestry, options)
        end

        # Useful when performing group searches by traversal_id to prevent
        # access to projects in the group hierarchy that the user does not have
        # permission to view.
        def rejected_project_filter(namespaces, options)
          current_user = options[:current_user]
          scoped_project_ids = scoped_project_ids(current_user, options[:project_ids])
          return {} if scoped_project_ids == :any

          project_ids = []
          Array.wrap(options[:features]).each do |feature|
            project_ids.concat(filter_ids_by_feature(scoped_project_ids, current_user, feature))
          end

          rejected_ids = namespaces.flat_map do |namespace|
            namespace.all_project_ids_except(project_ids).pluck_primary_key
          end

          {
            terms: {
              _name: context.name,
              "#{options[:project_id_field]}": rejected_ids
            }
          }
        end

        def traversal_ids_ancestry_filter(query_hash, namespace_ancestry, options)
          context.name(:namespace) do
            add_filter(query_hash, :query, :bool, :filter) do
              ancestry_filter(options[:current_user],
                namespace_ancestry,
                prefix: options.fetch(:traversal_ids_prefix, :traversal_ids)
              )
            end
          end
        end

        def ancestry_filter(current_user, namespace_ancestry, prefix:)
          return {} unless current_user
          return {} if namespace_ancestry.blank?

          context.name(:ancestry_filter) do
            filters = namespace_ancestry.map do |namespace_ids|
              {
                prefix: {
                  "#{prefix}": {
                    _name: context.name(:descendants),
                    value: namespace_ids
                  }
                }
              }
            end

            {
              bool: {
                should: filters
              }
            }
          end
        end

        def filter_ids_by_feature(project_ids, user, feature)
          Project
            .id_in(project_ids)
            .filter_by_feature_visibility(feature, user)
            .pluck_primary_key
        end

        def find_labels_by_name(names, options)
          raise ArgumentError, 'search_level is a required option' unless options.key?(:search_level)

          return [] unless names.any?

          search_level = options[:search_level].to_sym
          project_ids = options[:project_ids]
          group_ids = options[:group_ids]

          finder_params = { name: names }

          case search_level
          when :global
          # no-op
          # no group or project filtering applied
          when :group
            finder_params[:group_id] = group_ids.first if group_ids&.any?
          when :project
            finder_params[:group_id] = group_ids.first if group_ids&.any?
            finder_params[:project_ids] = project_ids if project_ids != :any && project_ids&.any?
          else
            raise ArgumentError, 'Invalid search_level option provided'
          end

          labels = LabelsFinder.new(nil, finder_params).execute(skip_authorization: true)
          labels.each_with_object(Hash.new { |h, k| h[k] = [] }) do |label, hash|
            hash[label.name] << label.id
          end
        end
      end
    end
  end
end
