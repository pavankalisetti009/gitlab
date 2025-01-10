# frozen_string_literal: true

module Gitlab
  module Repositories
    class SnippetRepository < Gitlab::Repositories::RepoType
      def initialize
        @access_checker_class = Gitlab::GitAccessSnippet
        @guest_read_ability = :read_snippet
      end

      def name = :snippet

      def container_class = Snippet

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

      def project_resolver(snippet)
        snippet&.project
      end
    end
  end
end
