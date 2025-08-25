# frozen_string_literal: true

module Types
  module Security
    class AttributeType < BaseObject
      graphql_name 'SecurityAttribute'
      description 'A security attribute'

      authorize :read_security_attribute

      field :color, Types::ColorType,
        null: false,
        description: 'Color of the security attribute.'
      field :description, GraphQL::Types::String,
        null: true,
        description: 'Description of the security attribute.'
      field :editable_state, Types::Security::EditableStateEnum,
        null: false,
        description: 'Editable state of the security attribute.'
      field :id, Types::GlobalIDType[::Security::Attribute],
        null: false,
        description: 'Global ID of the security attribute.'
      field :name, GraphQL::Types::String,
        null: false,
        description: 'Name of the security attribute.'
      field :security_category, Types::Security::CategoryType,
        null: false,
        description: 'Security category the attribute belongs to.'
    end
  end
end
