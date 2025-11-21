# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- always authorized by Resolver
      # rubocop: disable GraphQL/GraphqlName -- graphql_name is generated automatically
      # rubocop: disable Graphql/GraphqlNamePosition -- graphql_name is generated automatically

      # Factory class for dynamically creating feature-specific user metric types
      class FeatureUserMetricType
        def self.[](feature)
          Class.new(BaseObject) do
            graphql_name "#{feature.to_s.camelize(:lower)}UserMetrics"
            description "#{feature.to_s.titleize} user metrics for a user. " \
              "Requires ClickHouse. Premium and Ultimate with GitLab Duo Enterprise only."

            extend ::Analytics::AiEventFields

            field :total_event_count, GraphQL::Types::Int,
              description: "Total count of all #{feature.to_s.titleize} events for the user.",
              null: true

            exposed_events(feature).each do |event_name|
              field_name = count_field_name(event_name)
              field field_name, GraphQL::Types::Int,
                description: "Total count of `#{event_name}` event."

              define_method(field_name) do
                object[field_name] || 0
              end
            end

            define_method(:total_event_count) do
              self.class.exposed_events(feature).sum { |event| object[self.class.count_field_name(event)] || 0 }
            end
          end
        end
      end
      # rubocop: enable Graphql/AuthorizeTypes
      # rubocop: enable GraphQL/GraphqlName
      # rubocop: enable Graphql/GraphqlNamePosition
    end
  end
end
