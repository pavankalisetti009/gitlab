# frozen_string_literal: true

module Search
  module Zoekt
    class SearchRequest
      def initialize(current_user:, query:, **options)
        @query = query
        @current_user = current_user
        @options = options
        @use_traversal_id_queries = ::Search::Zoekt.feature_available?(
          :traversal_id_search, current_user, group_id: options[:group_id], project_id: options[:project_id]
        )
      end

      def as_json
        {
          version: 2,
          timeout: options.fetch(:timeout, '120s'),
          num_context_lines: options.fetch(:num_context_lines),
          max_file_match_window: options.fetch(:max_file_match_window),
          max_file_match_results: options.fetch(:max_file_match_results),
          max_line_match_window: options.fetch(:max_line_match_window),
          max_line_match_results: options.fetch(:max_line_match_results),
          max_line_match_results_per_file: options.fetch(:max_line_match_results_per_file),
          forward_to: use_traversal_id_queries? ? build_node_queries : build_node_queries_from_targets
        }
      end

      def project_level?
        search_level.project?
      end

      def group_level?
        search_level.group?
      end

      def global_level?
        search_level.global?
      end

      private

      def build_node_queries
        builder_options = {
          current_user: current_user,
          search_level: search_level.as_sym,
          group_id: options[:group_id],
          project_id: options[:project_id],
          filters: options[:filters],
          use_traversal_id_queries: use_traversal_id_queries?
        }

        nodes.map do |node|
          CodeQueryBuilder.build(query: query, options: builder_options).tap do |payload|
            payload[:endpoint] = node.search_base_url
          end
        end
      end

      def build_node_queries_from_targets
        raise ArgumentError, 'No targets specified for the search request' unless options[:targets].present?

        options[:targets].filter_map do |node_id, repo_ids|
          node = ::Search::Zoekt::Node.find_by_id(node_id)
          next if node.nil?

          builder_options = {
            repo_ids: repo_ids,
            use_traversal_id_queries: use_traversal_id_queries?
          }

          CodeQueryBuilder.build(query: query, options: builder_options).tap do |payload|
            payload[:endpoint] = node.search_base_url
          end
        end
      end

      def nodes
        @nodes ||= if search_level.project?
                     ::Search::Zoekt::Node.for_search.online.searchable_for_project(options[:project_id])
                   elsif search_level.group?
                     fetch_searchable_nodes_for_namespace
                   else
                     ::Search::Zoekt::Node.for_search.online
                   end
      end

      def fetch_searchable_nodes_for_namespace
        enabled_namespace = root_ancestor&.zoekt_enabled_namespace

        if enabled_namespace.blank?
          raise ArgumentError, "No enabled namespace found for root ancestor: #{root_ancestor.inspect}"
        end

        enabled_namespace.nodes.for_search.online.tap do |n|
          raise ArgumentError, "No online nodes found for namespace: #{enabled_namespace.inspect}" if n.empty?
        end
      end

      def root_ancestor
        @root_ancestor ||= if search_level.group?
                             ::Group.find(options[:group_id]).root_ancestor
                           elsif search_level.project?
                             ::Project.find(options[:project_id]).root_ancestor
                           end
      end

      def use_traversal_id_queries?
        @use_traversal_id_queries
      end

      def search_level
        @search_level ||= ::Search::Level.new(options)
      end

      attr_reader :query, :current_user, :options
    end
  end
end
