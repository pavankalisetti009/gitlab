# frozen_string_literal: true

module Sbom
  class BuildDependencyGraph
    include Gitlab::Utils::StrongMemoize

    BATCH_SIZE = 250

    def self.execute(project)
      new(project).execute
    end

    def initialize(project)
      @project = project
      @cache_key_service = Sbom::LatestGraphTimestampCacheKey.new(project: project)
      @all_paths = {}
      # This cache tracks a list of top-level nodes reachable from a given ancestor and the respective distance.
      # Any node in the graph could reach multiple top-level nodes, hence why this is a Set.
      # It is shared between all traversals so later traversals benefit from earlier searching, removing
      # significant repeated work.
      @cache = Hash.new { |hash, key| hash[key] = Set.new }
      @stats = { cache_hit: 0, cache_miss: 0 }
    end

    def timestamp
      Time.zone.now
    end
    strong_memoize_attr :timestamp

    def execute
      new_graph = build_dependency_graph

      # This can raise ActiveRecord::RecordInvalid because another Ci::Pipeline can start removing Sbom::Occurrence
      # rows which will prevent this job from finishing successfully.
      #
      # This actually works in our favour since it's a clear indication we can leave the graph processing to the
      # newest job.
      bulk_insert_paths(new_graph)

      @cache_key_service.store(new_graph.first.created_at) unless new_graph.empty?

      # Schedule removal, this job is idempotent and deduplicated so we can schedule it many times
      Sbom::RemoveOldDependencyGraphsWorker.perform_async(project.id)
    end

    private

    attr_reader :project, :all_paths, :cache, :stats

    def build_dependency_graph
      create_graph_edges

      # `graph` is an adjacency list of descendant->parent edges for a given descendant.
      graph = Hash.new { |hash, key| hash[key] = [] }

      all_ancestors = []
      # Build an adjacency list from the direct paths
      all_paths.each_value do |path|
        graph[path[:descendant_id]] << path
        all_ancestors << path[:ancestor_id]
      end

      # Leaf nodes are where we will start our full traversal from. The graph is keyed by descendant,
      # so leaf nodes are all descendants (graph.keys) that are never found as an ancestor.
      leaf_nodes = graph.keys - all_ancestors

      # Let's get buildin' the graph!
      leaf_nodes.each do |leaf|
        graph[leaf].each do |ancestor|
          iterate_path(graph, ancestor)
        end
      end

      stats_total = stats[:cache_hit] + stats[:cache_miss]

      ::Gitlab::AppLogger.info(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.namespace&.name,
        namespace_id: project.namespace&.id,
        count_path_nodes: all_paths.count,
        cache_hit: stats[:cache_hit],
        cache_miss: stats[:cache_miss],
        cache_hit_rate: stats_total > 0 ? stats[:cache_hit].to_f / stats_total : 0,
        cache_miss_rate: stats_total > 0 ? stats[:cache_miss].to_f / stats_total : 0
      )
      all_paths.values
    end

    def create_graph_edges
      sbom_occurrences.each do |occurrence|
        next if occurrence.ancestors.empty?

        occurrence.ancestors.each do |ancestor|
          next if ancestor.empty?

          ancestor_name = ancestor['name']
          ancestor_version = ancestor['version']

          parent_occurrence = find_parent_sbom_occurrence(
            ancestor_name,
            ancestor_version,
            occurrence.input_file_path
          )

          next unless parent_occurrence

          # Create a direct path
          collect(parent_occurrence.id, occurrence.id, 1, parent_occurrence.top_level?)
        end
      end
    end

    def iterate_path(graph, current_node, current_path = [], depth = 1)
      collect_path(current_path, current_node, depth, false) if current_node.top_level_ancestor
      # We don't stop processing if we find a top_level_ancestor. A node can be a top_level node which is also
      # a descendant of another top_level node. We must keep searching.
      ancestors = graph[current_node.ancestor_id]
      return unless ancestors

      current_path << current_node

      ancestors.each do |ancestor|
        # Check for a cycle. If we find one we can safely stop processing this step.
        next if current_path.any? { |path| path.ancestor_id == ancestor.ancestor_id }

        # Have we already traversed this path?
        if cache[ancestor.descendant_id].present? && cache[ancestor.ancestor_id].present?
          # For each top_level_ancestor we've already found from this descendant:
          cache[ancestor.descendant_id].each do |top_level_ancestor|
            collect_path(current_path, top_level_ancestor[:top_level], depth + top_level_ancestor[:depth], true)
          end
        else
          iterate_path(graph, ancestor, current_path.clone, depth + 1)
        end
      end
    end

    def collect_path(current_path, top_level_ancestor, depth, cache_hit)
      current_path.each do |partial|
        collect(top_level_ancestor.ancestor_id, partial.descendant_id, depth, true)
        # Cache that this path partial can reach this top_level_ancestor.
        cache[partial.descendant_id] << { top_level: top_level_ancestor, depth: depth }
        stats[cache_hit ? :cache_hit : :cache_miss] += 1
        depth -= 1
      end
    end

    def collect(ancestor_id, descendant_id, path_length, top_level)
      key = "#{ancestor_id}-#{descendant_id}-#{path_length}"
      return if all_paths.has_key?(key)

      all_paths[key] = Sbom::GraphPath.new(
        ancestor_id: ancestor_id,
        descendant_id: descendant_id,
        project_id: project.id,
        path_length: path_length,
        created_at: timestamp,
        updated_at: timestamp,
        top_level_ancestor: top_level
      )
    end

    def bulk_insert_paths(paths)
      paths.each_slice(BATCH_SIZE) do |slice|
        Sbom::GraphPath.bulk_insert!(slice)
      end
    end

    def sbom_occurrences
      Sbom::Occurrence.by_project_ids(project.id).with_version.order_by_id
    end
    strong_memoize_attr :sbom_occurrences

    # This is convoluted *but*:
    # `Sbom::Occurrence#ancestors` is `Array[Hash]`.
    # Every Hash is { "name": "something", "version": "something" }.
    # We need to find corresponding Sbom::Occurrence for that particular pair (Node, for example, allows two
    # versions of the same package in a single project)
    # This, usually, should give you exactly one record except it doesn't because monorepos are a thing
    # (it's perfectly fine to have two Rails applications depending on `activesupport`).
    def find_parent_sbom_occurrence(ancestor_name, ancestor_version, child_input_file_path)
      sbom_occurrences
        .find do |occurrence|
          occurrence.component_name.eql?(ancestor_name) &&
            occurrence.input_file_path.eql?(child_input_file_path) &&
            occurrence.version.eql?(ancestor_version)
        end
    end
  end
end
