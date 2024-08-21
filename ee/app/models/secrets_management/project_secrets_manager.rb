# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsManager < ApplicationRecord
    STATUSES = {
      provisioning: 0,
      active: 1
    }.freeze

    self.table_name = 'project_secrets_managers'

    belongs_to :project

    validates :project, presence: true

    state_machine :status, initial: :provisioning do
      state :provisioning, value: STATUSES[:provisioning]
      state :active, value: STATUSES[:active]

      event :activate do
        transition all - [:active] => :active
      end
    end

    def ci_secrets_mount_path
      [
        namespace_path,
        "project_#{project.id}",
        'ci'
      ].compact.join('/')
    end

    private

    def namespace_path
      return unless project.namespace.type == "User"

      [
        project.namespace.type.downcase,
        project.namespace.id.to_s
      ].join('_')
    end
  end
end
