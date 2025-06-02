# frozen_string_literal: true

module Sbom
  class PathFinder
    attr_reader :occurrence

    def self.execute(sbom_occurrence)
      new(sbom_occurrence).execute
    end

    def initialize(sbom_occurrence)
      @occurrence = sbom_occurrence
    end

    def execute
      project_id = occurrence.project_id
      target_id = occurrence.id

      parents = build_parent_mapping(project_id)

      id_paths = find_all_id_paths(target_id, parents)

      occurrence_paths = convert_id_paths_to_occurrences(id_paths)

      add_top_level_path_if_needed(occurrence_paths, occurrence)

      occurrence_paths
    end

    private

    def build_parent_mapping(project_id)
      parents = {}

      # Use each_batch to efficiently process records in batches
      Sbom::GraphPath.by_projects(project_id).by_path_length(1).each_batch(of: 1000) do |batch|
        batch.each do |path|
          parents[path.descendant_id] ||= []
          parents[path.descendant_id] << path.ancestor_id
        end
      end

      parents
    end

    def find_all_id_paths(target_id, parents)
      completed_paths = []

      # First find all potential root nodes
      root_nodes = find_root_nodes(parents)

      # For each root, start a path towards the target
      root_nodes.each do |root_id|
        find_paths_from_root(root_id, target_id, parents, [], completed_paths, Set.new)
      end

      # Default path if none found
      completed_paths << [target_id] if completed_paths.empty?

      completed_paths
    end

    def find_root_nodes(parents)
      # Get all nodes mentioned in the graph
      all_nodes = Set.new

      parents.each do |child, parent_list|
        all_nodes.add(child)
        parent_list.each { |parent| all_nodes.add(parent) }
      end

      # Nodes that aren't children of any other node are roots
      all_nodes.select do |node|
        !parents.key?(node) || parents[node].empty?
      end
    end

    def find_paths_from_root(current, target, parents, path_so_far, completed_paths, visited)
      # Add current node to path
      current_path = path_so_far + [current]

      # If we've reached the target, we have a complete path
      if current == target
        completed_paths << current_path
        return
      end

      # Skip if we've already visited this node on this path to avoid cycles
      return if visited.include?(current)

      visited_for_branch = visited.clone.add(current)

      # Find all children of the current node
      children = []
      parents.each do |child, parent_list|
        children << child if parent_list.include?(current)
      end

      # Continue DFS towards the target
      children.each do |child|
        find_paths_from_root(child, target, parents, current_path, completed_paths, visited_for_branch)
      end
    end

    def convert_id_paths_to_occurrences(id_paths)
      all_ids = id_paths.flatten.uniq
      occurrence_map = {}

      Sbom::Occurrence.id_in(all_ids).with_version.each_batch(of: 1000) do |batch|
        batch.each do |occurrence|
          occurrence_map[occurrence.id] = occurrence
        end
      end

      # Convert ID paths to occurrence paths
      id_paths.map do |path|
        path.map { |id| occurrence_map[id] }
      end
    end

    def add_top_level_path_if_needed(occurrence_paths, target_occurrence)
      has_single_path = occurrence_paths.any? do |p|
        p.length == 1 && p[0].id == target_occurrence.id
      end

      occurrence_paths << [target_occurrence] if target_occurrence.top_level? && !has_single_path

      occurrence_paths
    end
  end
end
