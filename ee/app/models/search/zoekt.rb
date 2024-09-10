# frozen_string_literal: true

module Search
  module Zoekt
    EXPIRED_SUBSCRIPTION_GRACE_PERIOD = 30.days

    class << self
      include Gitlab::Utils::StrongMemoize

      def search?(container)
        root_namespace_id = fetch_root_namespace_id(container)
        return false unless root_namespace_id

        if search_with_replica?(container, root_namespace_id)
          Replica.search_enabled?(root_namespace_id)
        else
          Index.for_root_namespace_id_with_search_enabled(root_namespace_id).ready.exists?
        end
      end

      def index?(container)
        root_namespace_id = fetch_root_namespace_id(container)
        return false unless root_namespace_id

        Index.for_root_namespace_id(root_namespace_id).exists?
      end

      def enabled_for_user?(user)
        return false unless ::License.feature_available?(:zoekt_code_search)
        return false unless ::Gitlab::CurrentSettings.zoekt_search_enabled?
        return true unless user # anonymous users have access, the final check is the user's preference setting

        user.enabled_zoekt?
      end

      def index_async(project_id, _options = {})
        IndexingTaskWorker.perform_async(project_id, :index_repo) if create_indexing_tasks_enabled?(project_id)
      end

      def index_in(delay, project_id, _options = {})
        return unless create_indexing_tasks_enabled?(project_id)

        IndexingTaskWorker.perform_async(project_id, :index_repo, { delay: delay })
      end

      def delete_async(project_id, root_namespace_id:, node_id: nil)
        return unless create_indexing_tasks_enabled?(project_id)

        Router.fetch_nodes_for_indexing(project_id, root_namespace_id: root_namespace_id,
          node_ids: [node_id]).map do |node|
          options = { root_namespace_id: root_namespace_id, node_id: node.id }
          IndexingTaskWorker.perform_async(project_id, :delete_repo, options)
        end
      end

      def delete_in(delay, project_id, root_namespace_id:, node_id: nil)
        return unless create_indexing_tasks_enabled?(project_id)

        Router.fetch_nodes_for_indexing(project_id, root_namespace_id: root_namespace_id,
          node_ids: [node_id]).map do |node|
          options = {
            root_namespace_id: root_namespace_id, node_id: node.id, delay: delay
          }
          IndexingTaskWorker.perform_async(project_id, :delete_repo, options)
        end
      end

      private

      def create_indexing_tasks_enabled?(project_id)
        Feature.enabled?(:zoekt_create_indexing_tasks, Project.actor_from_id(project_id))
      end

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

      def search_with_replica?(container, root_namespace_id)
        return false if container.is_a? Project

        Feature.enabled?(:zoekt_search_with_replica, Namespace.actor_from_id(root_namespace_id))
      end
    end
  end
end
