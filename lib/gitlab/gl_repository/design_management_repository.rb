# frozen_string_literal: true

module Gitlab
  class GlRepository
    class DesignManagementRepository < Gitlab::GlRepository::RepoType
      def initialize
        @access_checker_class = ::Gitlab::GitAccessDesign
        @repository_resolver = ->(design_management_repository) { design_management_repository.repository }
        @project_resolver = ->(design_management_repository) { design_management_repository&.project }
        @suffix = :design
        @container_class = DesignManagement::Repository
      end

      def name = :design
    end
  end
end
