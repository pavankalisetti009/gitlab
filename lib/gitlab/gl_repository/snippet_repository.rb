# frozen_string_literal: true

module Gitlab
  class GlRepository
    class SnippetRepository < Gitlab::GlRepository::RepoType
      def initialize
        @name = :snippet
        @access_checker_class = Gitlab::GitAccessSnippet
        @repository_resolver = ->(snippet) do
          ::Repository.new(snippet.full_path, snippet, shard: snippet.repository_storage,
            disk_path: snippet.disk_path, repo_type: SNIPPET)
        end
        @container_class = Snippet
        @project_resolver = ->(snippet) { snippet&.project }
        @guest_read_ability = :read_snippet
      end
    end
  end
end
