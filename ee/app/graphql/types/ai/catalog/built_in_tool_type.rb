# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      # rubocop: disable Graphql/AuthorizeTypes -- Permissions are still to be determined https://gitlab.com/gitlab-org/gitlab/-/issues/553928
      class BuiltInToolType < ::Types::BaseObject
        graphql_name 'AiCatalogBuiltInTool'
        description 'An AI catalog built-in tool'

        field :description, String, null: false, description: 'Description of the built-in tool.'
        field :id, ::Types::GlobalIDType[::Ai::Catalog::BuiltInTool], null: false,
          description: 'Global ID of the built-in tool.'
        field :name, String, null: false, description: 'Name of the built-in tool.'
        field :title, String, null: false, description: 'Title of the built-in tool.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
