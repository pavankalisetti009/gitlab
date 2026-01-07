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
    let(:metrics_response) do
      {
        user.id => {
          total_events_count: 25,
          code_suggestions_accepted_count: 10,
          duo_chat_interactions_count: 15
        }
      }
    end

    let(:context) do
      {
        current_user: user,
        ai_metrics_params: {}
      }
    end

    before do
      allow_next_instance_of(::Analytics::AiAnalytics::AiUserMetricsService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: metrics_response)
        )
      end
    end

    it 'returns the total event count from the service' do
      result = batch_sync do
        resolve_field(:total_event_count, user, ctx: context)
      end

      expect(result).to eq(25)
    end

    it 'calls the service with all_features parameter' do
      expect(::Analytics::AiAnalytics::AiUserMetricsService).to receive(:new).with(
        hash_including(feature: :all_features)
      ).and_call_original

      batch_sync { resolve_field(:total_event_count, user, ctx: context) }
    end

    context 'when no metrics are available' do
      let(:metrics_response) { { user.id => {} } }

      it 'returns 0' do
        result = batch_sync do
          resolve_field(:total_event_count, user, ctx: context)
        end

        expect(result).to eq(0)
      end
    end

    context 'when service returns empty payload' do
      before do
        allow_next_instance_of(::Analytics::AiAnalytics::AiUserMetricsService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: {})
          )
        end
      end

      it 'returns 0' do
        result = batch_sync do
          resolve_field(:total_event_count, user, ctx: context)
        end

        expect(result).to eq(0)
      end
    end
  end
end
