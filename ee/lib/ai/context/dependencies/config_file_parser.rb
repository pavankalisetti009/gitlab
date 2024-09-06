# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      # This class finds and parses dependency configuration files on the repository's default branch
      class ConfigFileParser
        include Gitlab::Utils::StrongMemoize
        include ConfigFiles::Constants

        # This limits the directory levels we search through, which reduces the number of glob
        # comparisons we need to make with `File.fnmatch?` (via `ConfigFiles::Base.matches?`).
        MAX_SEARCH_DEPTH = 2

        def initialize(project)
          @project = project
          @repository = project.repository
        end

        def extract_config_files
          config_file_path_to_class_map = find_config_file_paths_with_class
          return [] unless config_file_path_to_class_map.present?

          blobs = fetch_blobs(config_file_path_to_class_map.keys)

          config_files = blobs.map do |blob|
            config_file_path_to_class_map[blob.path].new(blob)
          end

          config_files.each(&:parse!)
        end

        private

        attr_reader :project, :repository

        def worktree_paths
          paths = repository.ls_files(default_branch)
          paths.reject { |path| path.count('/') > MAX_SEARCH_DEPTH }
        end
        strong_memoize_attr :worktree_paths

        def default_branch
          project.default_branch
        end
        strong_memoize_attr :default_branch

        def latest_commit_sha
          project.commit(default_branch).sha
        end
        strong_memoize_attr :latest_commit_sha

        # Returns a hash in the form: { 'path1' => <config_file_class1>, 'path2' => 'config_file_class2', ... }
        # For each language, we return the first matching config file class,
        # processed in the order as they appear in `CONFIG_FILE_CLASSES`.
        def find_config_file_paths_with_class
          CONFIG_FILE_CLASSES.group_by(&:lang).each_with_object({}) do |(_lang, klasses), hash|
            klasses.each do |klass|
              matching_path = worktree_paths.find { |path| klass.matches?(path) }

              if matching_path
                hash[matching_path] = klass
                break
              end
            end
          end
        end

        def fetch_blobs(paths)
          paths_with_sha = paths.map { |path| [latest_commit_sha, path] }
          repository.blobs_at(paths_with_sha)
        end
      end
    end
  end
end
