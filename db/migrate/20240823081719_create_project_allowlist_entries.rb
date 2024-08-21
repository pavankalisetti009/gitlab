# frozen_string_literal: true

class CreateProjectAllowlistEntries < Gitlab::Database::Migration[2.2]
  milestone '17.4'

  def change
    create_table :project_allowlist_entries do |t|
      t.references :project, index: true, foreign_key: { on_delete: :cascade }, null: false
      t.integer :scanner, limit: 2, null: false
      t.text :description, limit: 255
      t.integer :type, limit: 2, null: false
      t.text :value, limit: 255, null: false
      t.boolean :active, null: false, default: true

      t.timestamps_with_timezone null: false
    end
  end
end
