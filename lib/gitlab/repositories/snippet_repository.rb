# frozen_string_literal: true

module Gitlab
  module Repositories
    class SnippetRepository < Gitlab::Repositories::RepoType
      include Singleton

      def name = :snippet

      def access_checker_class = Gitlab::GitAccessSnippet

      def guest_read_ability = :read_snippet

      def container_class = Snippet

      def project_for(snippet)
        snippet&.project
      end

      private

      def repository_resolver(snippet)
        ::Repository.new(
          snippet.full_path,
          snippet,
          shard: snippet.repository_storage,
          disk_path: snippet.disk_path,
          repo_type: Gitlab::GlRepository::SNIPPET
        )
      end
    end
  end
end
