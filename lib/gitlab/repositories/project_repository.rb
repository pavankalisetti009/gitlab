# frozen_string_literal: true

module Gitlab
  module Repositories
    class ProjectRepository < Gitlab::Repositories::RepoType
      include Singleton

      def name = :project

      def access_checker_class = Gitlab::GitAccessProject

      def guest_read_ability = :download_code

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

      def check_container(container)
        # Don't check container for projects because it accepts several container types.
      end
    end
  end
end
