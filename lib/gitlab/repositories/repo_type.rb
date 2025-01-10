# frozen_string_literal: true

module Gitlab
  module Repositories
    class RepoType
      attr_reader :access_checker_class,
        :container_class,
        :project_resolver,
        :guest_read_ability

      def initialize(
        access_checker_class:,
        container_class: default_container_class,
        project_resolver: nil,
        guest_read_ability: :download_code)
        @access_checker_class = access_checker_class
        @container_class = container_class
        @project_resolver = project_resolver
        @guest_read_ability = guest_read_ability
      end

      def name
        raise NotImplementedError, 'Define a name in a RepoType subclass'
      end

      def suffix = nil

      def identifier_for_container(container)
        "#{name}-#{container.id}"
      end

      def wiki?
        name == :wiki
      end

      def project?
        name == :project
      end

      def snippet?
        name == :snippet
      end

      def design?
        name == :design
      end

      def path_suffix
        suffix ? ".#{suffix}" : ''
      end

      def repository_for(container)
        check_container(container)
        return unless container

        repository_resolver(container)
      end

      def project_for(container)
        return container unless project_resolver

        project_resolver.call(container)
      end

      def valid?(repository_path)
        repository_path.end_with?(path_suffix) &&
          (
            !snippet? ||
            repository_path.match?(Gitlab::PathRegex.full_snippets_repository_path_regex)
          )
      end

      private

      def repository_resolver
        raise NotImplementedError, 'Define a repository_resolver in a RepoType subclass'
      end

      def default_container_class
        Project
      end

      def check_container(container)
        # Don't check container for wiki or project because these repo types
        # accept several container types.
        return if wiki? || project?

        return unless container.present? && container_class.present?
        return if container.is_a?(container_class)

        raise ContainerClassMismatchError.new(container.class.name, self)
      end
    end
  end
end

Gitlab::Repositories::RepoType.prepend_mod_with('Gitlab::Repositories::RepoType')
