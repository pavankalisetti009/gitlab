# frozen_string_literal: true

module Types
  module Sbom
    class DependencyType < BaseObject
      graphql_name 'Dependency'
      description 'A software dependency used by a project'

      implements Types::Sbom::DependencyInterface

      authorize :read_dependency

      field :has_dependency_paths, GraphQL::Types::Boolean,
        null: false, description: 'Indicates whether the dependency has any dependency paths.',
        method: :has_dependency_paths?, experiment: { milestone: '18.4' }
    end
  end
end
