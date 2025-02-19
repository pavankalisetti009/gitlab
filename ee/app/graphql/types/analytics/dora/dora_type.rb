# frozen_string_literal: true

module Types
  module Analytics
    module Dora
      # rubocop: disable Graphql/AuthorizeTypes -- authorized in resolver
      class DoraType < BaseObject
        graphql_name 'Dora'
        description 'All information related to DORA metrics.'

        field :metrics, [DoraMetricType],
          null: true,
          resolver: ::Resolvers::Analytics::Dora::DoraMetricsResolver,
          description: 'DORA metrics for the current group or project.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
