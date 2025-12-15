# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      class UserMetricsSortEnum < BaseEnum
        graphql_name 'AiUserMetricsSort'
        description 'Values for sorting AI user metrics.'

        Gitlab::Tracking::AiTracking.registered_features.each do |feature|
          value "#{feature}_TOTAL_COUNT_DESC".upcase,
            description: "#{feature.to_s.titleize} total event count in descending order.",
            value: { field: feature, direction: :desc }

          value "#{feature}_TOTAL_COUNT_ASC".upcase,
            description: "#{feature.to_s.titleize} total event count in ascending order.",
            value: { field: feature, direction: :asc }
        end
      end
    end
  end
end
