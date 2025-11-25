# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- authorized by parent type
      class CodeReviewMetricsType < BaseObject
        graphql_name 'codeReviewMetrics'
        description "Requires ClickHouse. Premium and Ultimate only."

        extend ::Analytics::AiEventFields

        COUNT_FIELD_SUFFIX =
          ::Analytics::AiAnalytics::UsageEventCountService::COUNT_FIELD_SUFFIX

        exposed_events(:code_review).each do |event_name|
          field (event_name + COUNT_FIELD_SUFFIX).to_sym, GraphQL::Types::Int,
            null: true,
            description: "Total count of `#{event_name}` event."
        end
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
