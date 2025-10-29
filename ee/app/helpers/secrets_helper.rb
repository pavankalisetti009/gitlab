# frozen_string_literal: true

module SecretsHelper
  def project_secrets_app_data(project)
    {
      project_path: project.full_path,
      base_path: project_secrets_path(project)
    }
  end

  def group_secrets_app_data(group)
    {
      group_path: group.full_path,
      base_path: group_secrets_path(group)
    }
  end
end
