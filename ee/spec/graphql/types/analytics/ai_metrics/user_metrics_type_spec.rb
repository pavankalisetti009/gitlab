# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiMetrics::UserMetricsType, feature_category: :value_stream_management do
  include GraphqlHelpers

  specify { expect(described_class.graphql_name).to eq('AiUserMetrics') }

  describe 'fields' do
    it 'has base fields' do
      expect(described_class).to have_graphql_field(:user)
      expect(described_class).to have_graphql_field(:total_event_count)
    end
  end

  describe 'feature fields' do
    it 'creates FeatureUserMetricType for each feature' do
      Gitlab::Tracking::AiTracking.registered_features.each do |feature|
        field = described_class.fields[feature.to_s.camelize(:lower)]
        expect(field.type.unwrap.graphql_name).to eq("#{feature.to_s.camelize(:lower)}UserMetrics")
      end
    end

    it 'uses titleized feature name in description' do
      Gitlab::Tracking::AiTracking.registered_features.each do |feature|
        field = described_class.fields[feature.to_s.camelize(:lower)]
        expect(field.description).to eq("#{feature.to_s.titleize} metrics for the user.")
      end
    end
  end

  describe 'deprecated fields' do
    it 'marks code_suggestions_accepted_count as deprecated' do
      field = described_class.fields['codeSuggestionsAcceptedCount']
      expect(field.deprecation_reason).to eq(
        'Use `codeSuggestions.codeSuggestionAcceptedInIdeEventCount` instead. Deprecated in GitLab 18.7.'
      )
    end

    it 'marks duo_chat_interactions_count as deprecated' do
      field = described_class.fields['duoChatInteractionsCount']
      expect(field.deprecation_reason).to eq(
        'Use `chat.requestDuoChatResponseEventCount` instead. Deprecated in GitLab 18.7.'
      )
    end
  end

  describe '#total_event_count' do
    let_it_be(:user) { create(:user) }

    let(:type_instance) do
      query = GraphQL::Query.new(GitlabSchema, document: nil, context: {}, variables: {})
      context = GraphQL::Query::Context.new(query: query, values: { current_user: user, ai_metrics_params: {} })
      described_class.authorized_new(user, context)
    end

    before do
      allow(type_instance).to receive(:load_metrics_for_feature).and_call_original
    end

    it 'only counts events accessed through count_field_name' do
      allow(described_class).to receive(:exposed_events)
        .with(:code_suggestions)
        .and_return(%w[
          code_suggestion_shown_in_ide
          code_suggestion_accepted_in_ide
          code_suggestion_rejected_in_ide
          imaginary_random_event
        ])

      other_features = Gitlab::Tracking::AiTracking.registered_features - [:code_suggestions]
      other_features.each do |feature|
        allow(described_class).to receive(:exposed_events)
          .with(feature)
          .and_call_original
      end

      allow(type_instance).to receive(:load_metrics_for_feature)
        .with(:code_suggestions)
        .and_return({
          code_suggestion_shown_in_ide_event_count: 10,
          code_suggestion_accepted_in_ide_event_count: 5,
          code_suggestion_rejected_in_ide_event_count: 3,
          imaginary_random_event: 10
        })

      allow(type_instance).to receive(:load_metrics_for_feature)
        .with(:chat)
        .and_return({
          request_duo_chat_response_event_count: 7
        })

      # Expected: 10 + 5 + 3  + 7 = 25 , Not including imaginary_random_event value
      expect(type_instance.total_event_count).to eq(25)
    end

    it 'returns 0 when no metrics are available' do
      Gitlab::Tracking::AiTracking.registered_features.each do |feature|
        allow(type_instance).to receive(:load_metrics_for_feature)
          .with(feature)
          .and_return({})
      end

      expect(type_instance.total_event_count).to eq(0)
    end
  end
end
