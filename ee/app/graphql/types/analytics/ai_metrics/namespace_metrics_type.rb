# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- always authorized by Resolver
      # rubocop: disable GraphQL/ExtractType -- no value for now
      class NamespaceMetricsType < BaseObject
        graphql_name 'AiMetrics'

        field :code_contributors_count, GraphQL::Types::Int,
          description: 'Number of code contributors.',
          null: true
        field :code_suggestions_accepted_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions accepted by code contributors.',
          null: true
        field :code_suggestions_contributors_count, GraphQL::Types::Int,
          description: 'Number of code contributors who used GitLab Duo Code Suggestions features.',
          null: true
        field :code_suggestions_shown_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions shown to code contributors.',
          null: true
        field :duo_chat_contributors_count, GraphQL::Types::Int,
          description: 'Number of contributors who used GitLab Duo Chat features.',
          null: true
        field :duo_pro_assigned_users_count, GraphQL::Types::Int,
          description: 'Number of assigned Duo Pro seats. Ignores time period filter and always returns current data.',
          null: true
      end
      # rubocop: enable GraphQL/ExtractType
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
