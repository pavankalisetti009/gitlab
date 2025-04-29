# frozen_string_literal: true

module Types
  module Sbom
    module DependencyInterface
      include Types::BaseInterface

      field :id, ::Types::GlobalIDType,
        null: false, description: 'ID of the dependency.'

      field :name, GraphQL::Types::String,
        null: false, description: 'Name of the dependency.'

      field :version, GraphQL::Types::String,
        null: true, description: 'Version of the dependency.'

      field :packager, Types::Sbom::PackageManagerEnum,
        null: true, description: 'Description of the tool used to manage the dependency.'

      field :location, Types::Sbom::LocationType,
        null: true, description: 'Information about where the dependency is located.'

      field :licenses, [Types::Sbom::LicenseType],
        null: true, description: 'Licenses associated to the dependency.'

      field :reachability, Types::Sbom::ReachabilityEnum,
        null: true, description: 'Information about reachability of a dependency.'

      field :vulnerability_count, GraphQL::Types::Int,
        null: false, description: 'Number of vulnerabilities within the dependency.'
    end
  end
end
