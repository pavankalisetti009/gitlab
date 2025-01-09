# frozen_string_literal: true

module Gitlab
  class GlRepository
    include Singleton

    PROJECT = Gitlab::GlRepository::ProjectRepository.new.freeze
    WIKI = Gitlab::GlRepository::WikiRepository.new.freeze
    SNIPPET = Gitlab::GlRepository::SnippetRepository.new.freeze
    DESIGN = ::Gitlab::GlRepository::DesignManagementRepository.new.freeze

    TYPES = {
      PROJECT.name.to_s => PROJECT,
      WIKI.name.to_s => WIKI,
      SNIPPET.name.to_s => SNIPPET,
      DESIGN.name.to_s => DESIGN
    }.freeze

    def self.types
      instance.types
    end

    def self.parse(gl_repository)
      identifier = ::Gitlab::GlRepository::Identifier.parse(gl_repository)

      repo_type = identifier.repo_type
      container = identifier.container

      [container, repo_type.project_for(container), repo_type]
    end

    def self.default_type
      PROJECT
    end

    def types
      TYPES
    end

    private_class_method :instance
  end
end
