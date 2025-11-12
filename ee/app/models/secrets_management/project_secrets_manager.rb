# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsManager < BaseSecretsManager
    include ProjectSecretsManagers::PipelineHelper
    include ProjectSecretsManagers::UserHelper

    self.table_name = 'project_secrets_managers'

    belongs_to :project, inverse_of: :secrets_manager

    validates :project, presence: true

    def namespace_path
      [project.namespace.type.downcase, project.namespace.id.to_s].join('_')
    end

    def project_path
      "project_#{project.id}"
    end

    def full_project_namespace_path
      [namespace_path, project_path].compact.join('/')
    end
  end
end
