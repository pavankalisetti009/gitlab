# frozen_string_literal: true

module Types
  module Analytics
    module AiUsage
      class AiUsageDataType < BaseObject
        graphql_name 'AiUsageData'

        authorize :read_ai_analytics

        field :code_suggestion_events,
          description: 'Events related to code suggestions feature.',
          resolver: ::Resolvers::Analytics::AiUsage::CodeSuggestionEventsResolver
      end
    end
  end
end
