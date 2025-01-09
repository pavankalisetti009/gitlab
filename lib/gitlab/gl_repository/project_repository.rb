# frozen_string_literal: true

module Gitlab
  class GlRepository
    class ProjectRepository < Gitlab::GlRepository::RepoType
      def initialize
        @name = :project
        @access_checker_class = Gitlab::GitAccessProject
        @repository_resolver = ->(project) do
          ::Repository.new(project.full_path, project, shard: project.repository_storage, disk_path: project.disk_path)
        end
      end
    end
  end
end
