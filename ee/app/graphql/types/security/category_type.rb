# frozen_string_literal: true

module Types
  module Security
    class CategoryType < BaseObject
      graphql_name 'SecurityCategory'
      description 'A security category'

      authorize :read_security_category

      field :description, GraphQL::Types::String,
        null: true,
        description: 'Description of the security category.'
      field :editable_state, Types::Security::EditableStateEnum,
        null: false,
        description: 'Editable state of the security category.'
      field :id, Types::GlobalIDType[::Security::Category],
        null: false,
        description: 'Global ID of the security category.'
      field :multiple_selection, GraphQL::Types::Boolean,
        null: false,
        description: 'Whether multiple attributes can be selected.'
      field :name, GraphQL::Types::String,
        null: false,
        description: 'Name of the security category.'
      field :security_attributes, [Types::Security::AttributeType],
        null: true,
        description: 'Security attributes belonging to the category.'
      field :template_type, Types::Security::CategoryTemplateTypeEnum,
        null: true,
        description: 'Template type for predefined categories.'
    end
  end
end
