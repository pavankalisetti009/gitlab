# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::Project do
  specify do
    expected_permissions = %i[
      create_path_lock
      read_path_locks
      admin_path_locks
      generate_description
      admin_work_item_lifecycle
      manage_ai_flow_triggers
      read_ai_catalog_items
      read_ai_catalog_item_consumers
      manage_ai_catalog_items
      manage_ai_catalog_item_consumers
    ]

    expected_permissions.each do |permission|
      expect(described_class).to have_graphql_field(permission)
    end
  end
end
