# frozen_string_literal: true

module Gitlab
  module Repositories
    class DesignManagementRepository < Gitlab::Repositories::RepoType
      def initialize
        @access_checker_class = ::Gitlab::GitAccessDesign
      end

      def name = :design

      def suffix = :design

      def container_class = DesignManagement::Repository

      private

      def repository_resolver(design_management_repository)
        design_management_repository.repository
      end

      def project_resolver(design_management_repository)
        design_management_repository&.project
      end
    end
  end
end
