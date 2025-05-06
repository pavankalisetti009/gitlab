# frozen_string_literal: true

module Types
  module Security
    class AnalyzerGroupStatusType < BaseObject
      graphql_name 'AnalyzerGroupStatusType'
      description 'Counts for each analyzer status in the group and subgroups.'
      authorize :read_security_inventory

      field :namespace_id,
        type: GraphQL::Types::Int,
        null: false,
        description: 'Namespace ID.'

      field :analyzer_type,
        type: AnalyzerTypeEnum,
        null: false,
        description: 'Analyzer type.'

      field :success,
        type: GraphQL::Types::Int,
        null: false,
        description: 'Number of analyzers succeeded.'

      field :failure,
        type: GraphQL::Types::Int,
        null: false,
        description: 'Number of analyzers failed.'
    end
  end
end
