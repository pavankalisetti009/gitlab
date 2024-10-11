# frozen_string_literal: true

module Types
  module Issuables
    class CustomFieldType < BaseObject
      graphql_name 'CustomField'
      description 'Represents a custom field'

      connection_type_class Types::CountableConnectionType

      authorize :read_custom_field

      field :id, ::Types::GlobalIDType[::Issuables::CustomField],
        null: false, description: 'Global ID of the custom field.'

      field :name, GraphQL::Types::String,
        null: false, description: 'Name of the custom field.'

      field :field_type, ::Types::Issuables::CustomFieldTypeEnum,
        null: false, description: 'Type of custom field.'

      field :active, GraphQL::Types::Boolean,
        null: false, description: 'Whether the custom field is active.',
        method: :active?

      field :created_at, Types::TimeType,
        null: false, description: 'Timestamp when the custom field was created.'

      field :updated_at, Types::TimeType,
        null: false, description: 'Timestamp when the custom field was last updated.'

      field :select_options, [Types::Issuables::CustomFieldSelectOptionType],
        null: true, description: 'Available options for a select field.'

      field :work_item_types, [Types::WorkItems::TypeType],
        null: true, description: 'Work item types that the custom field is available on.'
    end
  end
end
