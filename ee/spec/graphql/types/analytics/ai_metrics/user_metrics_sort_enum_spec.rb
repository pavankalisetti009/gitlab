# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiMetrics::UserMetricsSortEnum, feature_category: :value_stream_management do
  specify { expect(described_class.graphql_name).to eq('AiUserMetricsSort') }

  it 'dynamically generates sort values for each registered feature' do
    Gitlab::Tracking::AiTracking.registered_features.each do |feature|
      feature_name = feature.to_s.upcase

      expect(described_class.values).to include(
        "#{feature_name}_TOTAL_COUNT_DESC",
        "#{feature_name}_TOTAL_COUNT_ASC"
      )
    end
  end
end
