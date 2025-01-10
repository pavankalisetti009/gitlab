# frozen_string_literal: true

module Gitlab
  module Repositories
    class ProjectRepository < Gitlab::Repositories::RepoType
      def name = :project

      def access_checker_class = Gitlab::GitAccessProject

      def container_class = Project

      private

      def repository_resolver(project)
        ::Repository.new(
          project.full_path,
          project,
          shard: project.repository_storage,
          disk_path: project.disk_path
        )
      end

      # For project repository we always use the container, so a resolver is never used
      def project_resolver = nil
    end
  end
end
