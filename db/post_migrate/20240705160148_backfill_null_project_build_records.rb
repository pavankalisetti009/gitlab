# frozen_string_literal: true

class BackfillNullProjectBuildRecords < Gitlab::Database::Migration[2.2]
  milestone '17.2'
  restrict_gitlab_migration gitlab_schema: :gitlab_ci
  disable_ddl_transaction!

  BATCH_SIZE = 500

  def up
    builds_model = define_batchable_model('p_ci_builds')

    builds_model.where(project_id: nil).each_batch(column: :id) do |relation|
      connection.execute(
        <<~SQL
          UPDATE p_ci_builds
          SET project_id = (SELECT p.project_id FROM ci_pipelines p WHERE p.id = p_ci_builds.commit_id)
          WHERE id in (#{relation.select(:id).to_sql})
        SQL
      )
    end

    builds_model.where(project_id: nil).delete_all
  end

  def down
    # no-op
  end
end
