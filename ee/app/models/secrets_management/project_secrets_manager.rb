# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsManager < BaseSecretsManager
    include ProjectSecretsManagers::PipelineHelper
    include ProjectSecretsManagers::UserHelper

    self.table_name = 'project_secrets_managers'

    belongs_to :project, inverse_of: :secrets_manager

    validates :project, presence: true

    def self.build_namespace_path(namespace)
      [namespace.type.downcase, namespace.id.to_s].join('_')
    end

    def self.build_project_path(project)
      "project_#{project.id}"
    end

    def namespace_path
      self.class.build_namespace_path(project.namespace)
    end

    def project_path
      self.class.build_project_path(project)
    end

    def full_project_namespace_path
      [namespace_path, project_path].compact.join('/')
    end
  end
end
