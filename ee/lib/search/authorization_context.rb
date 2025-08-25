# frozen_string_literal: true

module Search
  class AuthorizationContext
    include ::Search::Elastic::Concerns::AuthorizationUtils

    def initialize(current_user)
      @current_user = current_user
    end

    def get_access_levels_for_feature(feature)
      get_feature_access_levels(feature)
    end

    def get_traversal_ids_for_group(group_id)
      ::Group.find(group_id).elastic_namespace_ancestry
    end

    # Supported options:
    # search_level
    # group_ids
    # project_ids
    def get_traversal_ids_for_groups(authorized_groups, options)
      get_traversal_ids_for_search_level(authorized_groups, options)
    end

    # Supported options:
    # min_access_level
    def get_groups_for_user(options)
      groups_for_user(user: current_user, min_access_level: options[:min_access_level])
    end

    # Supported options:
    # search_level
    # min_access_level
    # group_ids
    # project_ids
    def get_projects_for_user(options)
      min_access_level = options.fetch(:min_access_level)

      projects_for_user(current_user, options)
        .where_exists(current_user.authorizations_for_projects(min_access_level:))
    end

    private

    attr_reader :current_user
  end
end
