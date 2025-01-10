# frozen_string_literal: true

module Gitlab
  module Repositories
    class ProjectRepository < Gitlab::GlRepository::RepoType
      def initialize
        @access_checker_class = Gitlab::GitAccessProject
        @repository_resolver = ->(project) do
          ::Repository.new(project.full_path, project, shard: project.repository_storage, disk_path: project.disk_path)
        end
      end

      def name = :project
    end
  end
end
