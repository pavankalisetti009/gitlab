# frozen_string_literal: true

module Types
  module Sbom
    class DependencyPathType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- Authorization checks are implemented on the parent object.
      graphql_name 'DependencyPath'
      description 'Ancestor path of a given dependency.'

      field :path, [DependencyPathPartialType],
        null: false, description: 'Name of the dependency.'

      field :is_cyclic, GraphQL::Types::Boolean,
        null: false, description: 'Indicates if the path is cyclic.'

      field :max_depth_reached, GraphQL::Types::Boolean,
        null: false,
        description: "Indicates if the path reached the maximum depth (#{::Sbom::DependencyPath::MAX_DEPTH})."
    end
  end
end
