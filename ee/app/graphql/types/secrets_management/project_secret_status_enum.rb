# frozen_string_literal: true

module Types
  module SecretsManagement
    class ProjectSecretStatusEnum < BaseEnum
      graphql_name 'ProjectSecretStatus'
      description 'Status of project secret'

      value 'COMPLETED', 'Secret is complete.', value: ::SecretsManagement::ProjectSecret::STATUSES[:completed]
      value 'CREATE_STALE', 'Secret creation appears stale (started long ago or missing completion timestamp).',
        value: ::SecretsManagement::ProjectSecret::STATUSES[:create_stale]
      value 'UPDATE_STALE', 'Secret update appears stale (started long ago or missing completion timestamp).',
        value: ::SecretsManagement::ProjectSecret::STATUSES[:update_stale]
      value 'CREATE_IN_PROGRESS', 'Secret creation is in progress.',
        value: ::SecretsManagement::ProjectSecret::STATUSES[:create_in_progress]
      value 'UPDATE_IN_PROGRESS', 'Secret update is in progress.',
        value: ::SecretsManagement::ProjectSecret::STATUSES[:update_in_progress]
    end
  end
end
