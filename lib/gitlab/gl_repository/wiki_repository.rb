# frozen_string_literal: true

module Gitlab
  class GlRepository
    class WikiRepository < Gitlab::GlRepository::RepoType
      def initialize
        @access_checker_class = Gitlab::GitAccessWiki
        @repository_resolver = ->(container) do
          wiki = container.is_a?(Wiki) ? container : container.wiki # Also allow passing a Project, Group, or Geo::DeletedProject
          ::Repository.new(wiki.full_path, wiki, shard: wiki.repository_storage, disk_path: wiki.disk_path, repo_type: WIKI)
        end
        @container_class = ProjectWiki
        @project_resolver = ->(wiki) { wiki.try(:project) }
        @guest_read_ability = :download_wiki_code
      end

      def name = :wiki

      def suffix = :wiki
    end
  end
end
