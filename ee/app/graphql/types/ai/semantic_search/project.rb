# frozen_string_literal: true

module Types
  module Ai
    module SemanticSearch
      class Project < ::Types::BaseInputObject
        graphql_name 'ProjectInfoInput'
        description 'Project selector with optional path prefix for narrowing the search.'

        argument :project_id, GraphQL::Types::Int, required: true,
          description: 'Numeric project ID.'

        argument :directory_path, GraphQL::Types::String, required: false,
          description: 'Optional path prefix inside the repo (e.g., "app/models").'
      end
    end
  end
end
