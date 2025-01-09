# frozen_string_literal: true

module Gitlab
  class GlRepository
    class DesignManagementRepository < Gitlab::GlRepository::RepoType
      def initialize
        @name = :design
        @access_checker_class = ::Gitlab::GitAccessDesign
        @repository_resolver = ->(design_management_repository) { design_management_repository.repository }
        @project_resolver = ->(design_management_repository) { design_management_repository&.project }
        @suffix = :design
        @container_class = DesignManagement::Repository
      end
    end
  end
end
