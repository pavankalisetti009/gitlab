# frozen_string_literal: true

module SecretsManagement
  class SecretRotationInfo < ApplicationRecord
    self.table_name = 'secret_rotation_infos'

    MIN_ROTATION_DAYS = 7
    APPROACHING_THRESHOLD_DAYS = 7

    STATUSES = {
      overdue: 'OVERDUE',
      approaching: 'APPROACHING',
      ok: 'OK'
    }.freeze

    belongs_to :project, inverse_of: :secret_rotation_infos

    validates :secret_name, presence: true, length: { maximum: 255 }
    validates :secret_metadata_version, presence: true

    validates :rotation_interval_days,
      presence: true,
      numericality: { greater_than_or_equal_to: MIN_ROTATION_DAYS }

    # NOTE: We intentionally don't validate uniqueness of :secret_name scoped to :project_id + :secret_metadata_version
    # in Rails to avoid an extra DB query. The database unique index enforces this constraint.
    # Since we create these records internally, uniqueness violations should not occur in normal operation.

    def self.for_project_secret(project, name, secret_metadata_version)
      find_by(project_id: project.id, secret_name: name, secret_metadata_version: secret_metadata_version)
    end

    def upsert
      return false unless valid?

      result = self.class.upsert({
        project_id: project.id,
        secret_name: secret_name,
        secret_metadata_version: secret_metadata_version,
        rotation_interval_days: rotation_interval_days
      }, unique_by: %i[project_id secret_name secret_metadata_version])

      # result.rows contains `[[<id of record>]]`
      self.id = result.rows.first.first

      reset

      true
    end

    def status
      # TODO: Implement proper status logic once we address https://gitlab.com/gitlab-org/gitlab/-/issues/555421#note_2725874721
      # For now, this is just for UI testing purposes
      STATUSES.fetch(:ok)
    end
  end
end
