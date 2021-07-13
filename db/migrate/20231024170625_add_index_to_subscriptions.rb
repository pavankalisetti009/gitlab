# frozen_string_literal: true

# See https://docs.gitlab.com/ee/development/migration_style_guide.html
# for more information on how to write migrations for GitLab.

class AddIndexToSubscriptions < Gitlab::Database::Migration[2.1]
  disable_ddl_transaction!

  INDEX_NAME = 'index_subscriptions_on_user_and_project'

  def up
    add_concurrent_index :subscriptions, [:user_id, :project_id], name: INDEX_NAME
  end

  def down
    remove_concurrent_index :subscriptions, [:user_id, :project_id], name: INDEX_NAME
  end
end
