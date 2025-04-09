# frozen_string_literal: true

module Types
  module Ai
    module Chat
      # rubocop: disable Graphql/AuthorizeTypes -- does not require authorization as these are not user data
      class ContextPresetsType < Types::BaseObject
        graphql_name 'ContextPreset'
        description "Presets for GitLab Duo Chat window based on current context"

        field :questions,
          [GraphQL::Types::String],
          null: true,
          description: "Array of questions that the user can ask GitLab Duo Chat from the current page."
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
