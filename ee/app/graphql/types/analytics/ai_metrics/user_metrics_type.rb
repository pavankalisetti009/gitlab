# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- always authorized by Resolver
      class UserMetricsType < BaseObject
        graphql_name 'AiUserMetrics'
        description "Pre-aggregated per-user metrics for GitLab Code Suggestions and GitLab Duo Chat. " \
          "Require ClickHouse to be enabled and GitLab Ultimate with the Duo Enterprise add-on."

        extend ::Analytics::AiEventFields

        field :user, Types::GitlabSubscriptions::AddOnUserType,
          description: 'User associated with metrics.',
          null: false

        field :code_suggestions_accepted_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions accepted by the user.',
          null: true,
          deprecated: {
            reason: 'Use `codeSuggestions.codeSuggestionAcceptedInIdeEventCount` instead', milestone: '18.7'
          }

        field :duo_chat_interactions_count, GraphQL::Types::Int,
          description: 'Number of user interactions with GitLab Duo Chat.',
          null: true,
          deprecated: { reason: 'Use `chat.requestDuoChatResponseEventCount` instead', milestone: '18.7' }

        field :total_event_count, GraphQL::Types::Int,
          description: 'Total count of all tracked events for the user.',
          null: true

        Gitlab::Tracking::AiTracking.registered_features.each do |feature|
          field_description = "#{feature.to_s.titleize} metrics for the user."
          field feature, FeatureUserMetricType[feature],
            description: field_description,
            null: true
        end

        alias_method :user, :object

        Gitlab::Tracking::AiTracking.registered_features.each do |feature|
          define_method(feature) do
            load_metrics_for_feature(feature)
          end
        end

        def code_suggestions_accepted_count
          ::Gitlab::Graphql::Lazy.with_value(load_metrics_for_feature(:code_suggestions)) do |metrics|
            metrics[:code_suggestion_accepted_in_ide_event_count] || 0
          end
        end

        def duo_chat_interactions_count
          ::Gitlab::Graphql::Lazy.with_value(load_metrics_for_feature(:chat)) do |metrics|
            metrics[:request_duo_chat_response_event_count] || 0
          end
        end

        def total_event_count
          all_features = Gitlab::Tracking::AiTracking.registered_features

          all_features.reduce(0) do |total, feature|
            lazy_metrics = load_metrics_for_feature(feature)
            forced_metrics = ::Gitlab::Graphql::Lazy.force(lazy_metrics)

            feature_total = self.class.exposed_events(feature).sum do |event|
              forced_metrics[self.class.count_field_name(event)] || 0
            end

            total + feature_total
          end
        end

        private

        def load_metrics_for_feature(feature)
          BatchLoader::GraphQL.for(user).batch(key: :"user_metrics_#{feature}") do |users, return_result|
            all_metrics = fetch_metrics_for_users(users, feature)
            users.each do |user|
              metrics = all_metrics[user.id] || {}
              return_result.call(user, metrics)
            end
          end
        end

        def fetch_metrics_for_users(users, feature)
          ::Analytics::AiAnalytics::AiUserMetricsService.new(
            current_user: context[:current_user],
            user_ids: users.map(&:id),
            namespace: context.dig(:ai_metrics_params, :namespace),
            from: context.dig(:ai_metrics_params, :start_date),
            to: context.dig(:ai_metrics_params, :end_date),
            feature: feature
          ).execute.payload
        end
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
