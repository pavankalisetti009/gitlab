# frozen_string_literal: true

module EE
  module Types
    module Namespaces
      module UserLevelPermissions
        extend ActiveSupport::Concern

        prepended do
          field :can_bulk_edit_epics,
            GraphQL::Types::Boolean,
            null: true,
            description: 'Whether the current user can bulk edit epics in the group.',
            fallback_value: false

          field :can_create_epic,
            GraphQL::Types::Boolean,
            null: true,
            description: 'Whether the current user can create epics in the group.',
            fallback_value: false
        end
      end
    end
  end
end
