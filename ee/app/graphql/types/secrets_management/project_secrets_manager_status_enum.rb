# frozen_string_literal: true

module Types
  module SecretsManagement
    class ProjectSecretsManagerStatusEnum < BaseEnum
      graphql_name 'ProjectSecretsManagerStatus'
      description 'Values for the project secrets manager status'

      value 'PROVISIONING', 'Secrets manager is being provisioned.',
        value: ::SecretsManagement::ProjectSecretsManager::STATUSES[:provisioning]

      value 'ACTIVE', 'Secrets manager has been provisioned and enabled.',
        value: ::SecretsManagement::ProjectSecretsManager::STATUSES[:active]

      value 'DEPROVISIONING', 'Secrets manager has is being deprovisioned.',
        value: ::SecretsManagement::ProjectSecretsManager::STATUSES[:deprovisioning]
    end
  end
end
