# frozen_string_literal: true

module Gitlab
  module Repositories
    class DesignManagementRepository < Gitlab::Repositories::RepoType
      include Singleton

      def name = :design

      def suffix = :design

      def access_checker_class = ::Gitlab::GitAccessDesign

      def guest_read_ability = :download_code

      def container_class = DesignManagement::Repository

      def project_for(design_management_repository)
        design_management_repository&.project
      end

      private

      def repository_resolver(design_management_repository)
        design_management_repository.repository
      end
    end
  end
end
