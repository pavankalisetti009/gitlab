# frozen_string_literal: true

module Gitlab
  module Repositories
    class WikiRepository < Gitlab::Repositories::RepoType
      include Singleton

      def name = :wiki

      def suffix = :wiki

      def access_checker_class = Gitlab::GitAccessWiki

      def guest_read_ability = :download_wiki_code

      def container_class = ProjectWiki

      def project_for(wiki)
        wiki.try(:project)
      end

      private

      def repository_resolver(container)
        # Also allow passing a Project, Group, or Geo::DeletedProject
        wiki = container.is_a?(Wiki) ? container : container.wiki

        ::Repository.new(
          wiki.full_path,
          wiki,
          shard: wiki.repository_storage,
          disk_path: wiki.disk_path,
          repo_type: Gitlab::GlRepository::WIKI
        )
      end

      def check_container(container)
        # Don't check container for wikis because it accepts several container types.
      end
    end
  end
end
