# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      # rubocop: disable Graphql/AuthorizeTypes -- public
      class ItemType < ::Types::BaseObject
        graphql_name 'AiCatalogItem'
        description 'An AI catalog item'

        connection_type_class ::Types::CountableConnectionType

        field :created_at, ::Types::TimeType, null: false, description: 'Date of creation.'
        field :description, GraphQL::Types::String, null: false, description: 'Description of the item.'
        field :id, GraphQL::Types::ID, null: false, description: 'ID of the item.'
        field :item_type,
          ItemTypeEnum,
          null: false,
          description: 'Type of the item.'
        field :name, GraphQL::Types::String, null: false, description: 'Name of the item.'
        field :project, ::Types::ProjectType, null: true, description: 'Project for the item.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
