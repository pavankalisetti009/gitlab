# frozen_string_literal: true

module Gitlab
  module Repositories
    class WikiRepository < Gitlab::Repositories::RepoType
      def name = :wiki

      def suffix = :wiki

      def access_checker_class = Gitlab::GitAccessWiki

      def guest_read_ability = :download_wiki_code

      def container_class = ProjectWiki

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

      def project_resolver(wiki)
        wiki.try(:project)
      end
    end
  end
end
