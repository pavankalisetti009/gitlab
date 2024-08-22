# frozen_string_literal: true

class CreateGroupAllowlistEntries < Gitlab::Database::Migration[2.2]
  milestone '17.4'

  def change
    create_table :group_allowlist_entries do |t|
      t.references :group, references: :namespaces, index: true,
        foreign_key: { to_table: :namespaces, on_delete: :cascade }, null: false
      t.integer :scanner, limit: 2, null: false
      t.text :description, limit: 255
      t.integer :type, limit: 2, null: false
      t.text :value, limit: 255, null: false
      t.boolean :active, null: false, default: true

      t.timestamps_with_timezone null: false
    end
  end
end
