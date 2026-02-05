# frozen_string_literal: true

module Types
  module Ai
    # rubocop: disable Graphql/AuthorizeTypes -- Always public
    class FoundationalChatAgentType < ::Types::BaseObject
      graphql_name 'AiFoundationalChatAgent'
      description 'Core Agent available for GitLab features.'

      field :avatar_url, GraphQL::Types::String, null: true,
        description: 'Avatar URL of the foundational chat agent.'
      field :description, GraphQL::Types::String, null: false,
        description: 'Description of the agent.'
      field :id, ::Types::GlobalIDType[::Ai::FoundationalChatAgent], null: false,
        description: 'Global ID of the foundational chat agent.'
      field :name, GraphQL::Types::String, null: false, description: 'Name of the agent.'
      field :reference, GraphQL::Types::String, null: false,
        description: 'Reference ID of the agent.'
      field :reference_with_version, GraphQL::Types::String,
        null: true, description: 'Versioned reference of the agent.'
      field :version, GraphQL::Types::String, null: true, description: 'Version of the agent.'

      def avatar_url
        return unless object.avatar

        ActionController::Base.helpers.image_path("bot_avatars/#{object.avatar}")
      end
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
