# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiMetrics::FeatureUserMetricType, feature_category: :value_stream_management do
  include GraphqlHelpers

  let(:current_user) { nil }

  describe '.[]' do
    it 'generates a GraphQL type for a given feature' do
      type = described_class[:code_suggestions]

      expect(type).to be < Types::BaseObject
      expect(type.graphql_name).to eq('codeSuggestionsUserMetrics')
      expect(type.description).to eq(
        'Code Suggestions user metrics for a user. ' \
          'Requires ClickHouse. Premium and Ultimate with GitLab Duo Enterprise only.'
      )
    end

    it 'generates different types for different features' do
      code_suggestions_type = described_class[:code_suggestions]
      chat_type = described_class[:chat]

      expect(code_suggestions_type).not_to eq(chat_type)
      expect(code_suggestions_type.graphql_name).to eq('codeSuggestionsUserMetrics')
      expect(chat_type.graphql_name).to eq('chatUserMetrics')
    end

    it 'extends Analytics::AiEventFields' do
      type = described_class[:code_review]

      expect(type.singleton_class.included_modules).to include(Analytics::AiEventFields)
    end

    it 'includes totalEventCount field' do
      type = described_class[:code_suggestions]

      expect(type.fields).to include('totalEventCount')
      expect(type.fields['totalEventCount'].type.unwrap).to eq(GraphQL::Types::Int)
      expect(type.fields['totalEventCount'].description).to eq(
        'Total count of all Code Suggestions events for the user.'
      )
    end

    it 'generates event count fields for the feature' do
      type = described_class[:code_suggestions]

      expect(type.fields).to include('codeSuggestionShownInIdeEventCount')
      expect(type.fields).to include('codeSuggestionAcceptedInIdeEventCount')
      expect(type.fields).to include('codeSuggestionRejectedInIdeEventCount')
    end

    describe '#total_event_count' do
      it 'sums only fields ending with _event_count' do
        type = described_class[:code_suggestions]
        data = {
          code_suggestion_shown_in_ide_event_count: 10,
          code_suggestion_accepted_in_ide_event_count: 5,
          code_suggestion_rejected_in_ide_event_count: 3,
          some_other_field: 100 # Should not be included in sum
        }
        instance = type.authorized_new(data, query_context)

        expect(instance.total_event_count).to eq(18)
      end

      it 'returns 0 when no event count fields are present' do
        type = described_class[:code_suggestions]
        instance = type.authorized_new({}, query_context)

        expect(instance.total_event_count).to eq(0)
      end
    end
  end
end
