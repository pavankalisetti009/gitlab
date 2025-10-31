# frozen_string_literal: true

module Types
  module Security
    module Attributes
      class BulkUpdateModeEnum < Types::BaseEnum
        graphql_name 'SecurityAttributeBulkUpdateMode'
        description 'Mode for bulk updating security attributes'

        value 'ADD', 'Add attributes to projects (keeps existing attributes).', value: :add
        value 'REMOVE', 'Remove attributes from projects.', value: :remove
      end
    end
  end
end
