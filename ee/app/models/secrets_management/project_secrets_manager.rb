# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsManager < BaseSecretsManager
    include ProjectSecretsManagers::PipelineHelper
    include ProjectSecretsManagers::UserHelper

    DEFAULT_SECRETS_LIMIT = 100

    self.table_name = 'project_secrets_managers'

    belongs_to :project, inverse_of: :secrets_manager

    validates :project, presence: true

    before_create :set_paths

    def full_project_namespace_path
      [namespace_path, project_path].compact.join('/')
    end

    def secrets_limit
      Gitlab::CurrentSettings.project_secrets_limit || DEFAULT_SECRETS_LIMIT
    end

    private

    def set_paths
      self.namespace_path = [project.namespace.type.downcase, project.namespace.id.to_s].join('_')
      self.project_path = "project_#{project.id}"
    end
  end
end
