# frozen_string_literal: true

module Search
  module Zoekt
    EXPIRED_SUBSCRIPTION_GRACE_PERIOD = 30.days
    MAX_INDICES_PER_REPLICA = 10
    MIN_SCHEMA_VERSION_FOR_TRAVERSAL_ID_SEARCH = 2531
    TRAVERSAL_ID_CHECK_CACHE_KEY = 'zoekt_traversal_id_searchable'
    TRAVERSAL_ID_CHECK_CACHE_PERIOD = 10.minutes

    class << self
      include Gitlab::Utils::StrongMemoize

      def search?(container)
        return false unless enabled?

        root_namespace_id = fetch_root_namespace_id(container)
        return false unless root_namespace_id

        if search_with_replica?(container, root_namespace_id)
          Replica.search_enabled?(root_namespace_id)
        else
          Index.for_root_namespace_id_with_search_enabled(root_namespace_id).ready.exists?
        end
      end

      def index?(container)
        return false unless licensed_and_indexing_enabled?

        root_namespace_id = fetch_root_namespace_id(container)
        return false unless root_namespace_id

        Index.for_root_namespace_id(root_namespace_id).exists?
      end

      def licensed_and_indexing_enabled?
        ::License.feature_available?(:zoekt_code_search) && ::Gitlab::CurrentSettings.zoekt_indexing_enabled?
      end

      def enabled?
        return false unless ::License.feature_available?(:zoekt_code_search)
        return false unless ::Gitlab::CurrentSettings.zoekt_search_enabled?

        true
      end

      def enabled_for_user?(user)
        return false unless enabled?
        return true unless user # anonymous users have access, the final check is the user's preference setting

        user.enabled_zoekt?
      end

      def use_traversal_id_queries?(user, project_id: nil, group_id: nil)
        return false unless Feature.enabled?(:zoekt_traversal_id_queries, user)

        # If traversal ID queries are globally available, we can skip further checks
        global_cache_key = [TRAVERSAL_ID_CHECK_CACHE_KEY, :globally_available]

        return true if Rails.cache.read(global_cache_key) == true

        if project_id
          traversal_id_searchable_for_project_search?(project_id)
        elsif group_id
          traversal_id_searchable_for_group_search?(group_id)
        else
          traversal_id_searchable_for_global_search?.tap do |globally_available|
            # Cache true result for a long time
            Rails.cache.write(global_cache_key, true, expires_in: 1.day) if globally_available
          end
        end
      end

      def traversal_id_searchable_for_project_search?(project_id)
        cache_key = [TRAVERSAL_ID_CHECK_CACHE_KEY, :project, project_id]

        Rails.cache.fetch(cache_key, expires_in: TRAVERSAL_ID_CHECK_CACHE_PERIOD) do
          ::Search::Zoekt::Repository
            .for_project_id(project_id)
            .minimum_schema_version.to_i >= MIN_SCHEMA_VERSION_FOR_TRAVERSAL_ID_SEARCH
        end
      end

      def traversal_id_searchable_for_group_search?(group_id)
        np = ::Namespace.find_by(id: group_id)
        return false unless np.present?

        znp = ::Search::Zoekt::EnabledNamespace.for_root_namespace_id(np.root_ancestor.id).first
        return false unless znp.present?

        cache_key = [TRAVERSAL_ID_CHECK_CACHE_KEY, :group, group_id]

        Rails.cache.fetch(cache_key, expires_in: TRAVERSAL_ID_CHECK_CACHE_PERIOD) do
          ::Search::Zoekt::Repository
            .for_zoekt_indices(znp.indices)
            .minimum_schema_version.to_i >= MIN_SCHEMA_VERSION_FOR_TRAVERSAL_ID_SEARCH
        end
      end

      def traversal_id_searchable_for_global_search?
        Rails.cache.fetch(TRAVERSAL_ID_CHECK_CACHE_KEY, expires_in: TRAVERSAL_ID_CHECK_CACHE_PERIOD) do
          ::Search::Zoekt::Repository.minimum_schema_version.to_i >= MIN_SCHEMA_VERSION_FOR_TRAVERSAL_ID_SEARCH
        end
      end

      def index_async(project_id)
        return false unless licensed_and_indexing_enabled?

        IndexingTaskWorker.perform_async(project_id, :index_repo)
      end

      def index_in(delay, project_id)
        return false unless licensed_and_indexing_enabled?

        IndexingTaskWorker.perform_async(project_id, :index_repo, { delay: delay })
      end

      def delete_async(project_id, root_namespace_id:, node_id: nil)
        return false unless licensed_and_indexing_enabled?

        Router.fetch_nodes_for_indexing(project_id, root_namespace_id: root_namespace_id,
          node_ids: [node_id]).map do |node|
          options = { root_namespace_id: root_namespace_id, node_id: node.id }
          IndexingTaskWorker.perform_async(project_id, :delete_repo, options)
        end
      end

      def delete_in(delay, project_id, root_namespace_id:, node_id: nil)
        return false unless licensed_and_indexing_enabled?

        Router.fetch_nodes_for_indexing(project_id, root_namespace_id: root_namespace_id,
          node_ids: [node_id]).map do |node|
          options = {
            root_namespace_id: root_namespace_id, node_id: node.id, delay: delay
          }
          IndexingTaskWorker.perform_async(project_id, :delete_repo, options)
        end
      end

      def bin_path
        Gitlab.config.zoekt.bin_path
      end

      def missing_repo?(project)
        !project.repo_exists? || project.empty_repo?
      end

      private

      def fetch_root_namespace_id(container)
        case container
        in Project | Namespace
          container.root_ancestor.id
        in Integer => root_namespace_id
          root_namespace_id
        else
          raise ArgumentError, "#{container.class} class is not supported"
        end
      end

      def search_with_replica?(container, _root_namespace_id)
        !container.is_a?(Project)
      end
    end
  end
end
