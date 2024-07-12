# frozen_string_literal: true

class UpdateRequirePatExpiryInApplicationSettings < Gitlab::Database::Migration[2.2]
  milestone '17.2'
  restrict_gitlab_migration gitlab_schema: :gitlab_main

  class BatchedBackgroundMigration < MigrationRecord
    self.table_name = 'batched_background_migrations'
  end

  def up
    migration = BatchedBackgroundMigration.find_by(
      job_class_name: 'CleanupPersonalAccessTokensWithNilExpiresAt',
      table_name: :personal_access_tokens,
      column_name: :id)

    # Token expiry is set via the CleanupPersonalAccessTokensWithNilExpiresAt migration.
    # The default value of TRUE in ApplicationSettings reflects that token expiry is enforced.
    # No need to update ApplicationSettings if the migration is not found.
    return if migration

    execute "UPDATE application_settings SET require_personal_access_token_expiry = FALSE"
  end

  # no-op
  def down; end
end
