# frozen_string_literal: true

module Gitlab
  module Repositories
    class WikiRepository < Gitlab::Repositories::RepoType
      def initialize
        @access_checker_class = Gitlab::GitAccessWiki
        @container_class = ProjectWiki
        @guest_read_ability = :download_wiki_code
      end

      def name = :wiki

      def suffix = :wiki

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
