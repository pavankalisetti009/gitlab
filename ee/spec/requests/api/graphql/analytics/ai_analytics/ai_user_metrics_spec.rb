# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'aiUserMetrics', :freeze_time, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, name: 'my-group') }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group) }
  let_it_be(:current_user) do
    create(:user, reporter_of: group).tap do |user|
      create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: add_on_purchase)
    end
  end

  let(:filter_params) { {} }
  let(:expected_filters) { {} }
  let(:service_payload) { {} }
  let(:fields) { ['user { id }'] }
  let(:ai_user_metrics_fields) { query_nodes(:aiUserMetrics, fields, args: filter_params) }

  def stub_service
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?)
      .with(current_user, :read_enterprise_ai_analytics, anything)
      .and_return(true)

    Gitlab::Tracking::AiTracking.registered_features.each do |feature|
      feature_payload = filter_service_payload_by_feature(service_payload, feature)

      allow_next_instance_of(Analytics::AiAnalytics::AiUserMetricsService,
        hash_including(current_user: current_user, feature: feature, **expected_filters)) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: feature_payload))
      end
    end
  end

  def filter_service_payload_by_feature(payload, feature)
    return {} if payload.empty?

    feature_events = Gitlab::Tracking::AiTracking.registered_events(feature).keys
    feature_event_keys = feature_events.map { |event| :"#{event}#{count_field_suffix}" }

    payload.transform_values do |user_metrics|
      user_metrics.slice(*feature_event_keys)
    end
  end

  shared_examples 'ai user metrics query' do
    before do
      stub_service
      post_graphql(query, current_user: current_user)
    end

    it 'returns user information' do
      expect(ai_user_metrics['nodes'].first['user']).to eq({ 'id' => current_user.to_global_id.to_s })
    end

    context 'with full feature data' do
      let(:fields) { ['user { id }', 'totalEventCount', *all_feature_fields_with_total] }
      let(:event_counts) { sample_event_counts }
      let(:service_payload) { { current_user.id => event_counts } }

      it 'returns total event count' do
        expected_total = event_counts.values.compact.sum
        expect(ai_user_metrics['nodes'].first['totalEventCount']).to eq(expected_total)
      end

      it 'includes all registered features' do
        response_node = ai_user_metrics['nodes'].first

        Gitlab::Tracking::AiTracking.registered_features.each do |feature|
          expect(response_node).to have_key(feature.to_s.camelize(:lower))
        end
      end

      it 'returns correct event counts for each feature' do
        response_node = ai_user_metrics['nodes'].first

        Gitlab::Tracking::AiTracking.registered_features.each do |feature|
          feature_key = feature.to_s.camelize(:lower)
          exposed_events_for(feature).each do |event|
            field_name = event_to_field_name(event)
            payload_key = :"#{event}#{count_field_suffix}"
            expected_value = event_counts[payload_key] || 0

            expect(response_node[feature_key][field_name]).to eq(expected_value)
          end
        end
      end

      it 'returns totalEventCount for each feature' do
        response_node = ai_user_metrics['nodes'].first

        Gitlab::Tracking::AiTracking.registered_features.each do |feature|
          feature_key = feature.to_s.camelize(:lower)
          feature_events = exposed_events_for(feature)
          expected_feature_total = feature_events.sum do |event|
            event_counts[:"#{event}#{count_field_suffix}"] || 0
          end

          expect(response_node[feature_key]['totalEventCount']).to eq(expected_feature_total)
        end
      end
    end

    context 'with partial data' do
      let(:fields) { ['user { id }', *all_feature_fields] }
      let(:service_payload) do
        first_feature = Gitlab::Tracking::AiTracking.registered_features.first
        first_event = exposed_events_for(first_feature).first

        { current_user.id => { "#{first_event}#{count_field_suffix}": 99 } }
      end

      it 'defaults missing event counts to 0' do
        response_node = ai_user_metrics['nodes'].first

        Gitlab::Tracking::AiTracking.registered_features.each do |feature|
          feature_key = feature.to_s.camelize(:lower)
          exposed_events_for(feature).each do |event|
            field_name = event_to_field_name(event)
            expect(response_node[feature_key][field_name]).to be >= 0
          end
        end
      end
    end

    context 'with empty data' do
      let(:fields) { ['user { id }', 'totalEventCount', *all_feature_fields] }
      let(:service_payload) { {} }

      it 'returns zero for total event count' do
        expect(ai_user_metrics['nodes'].first['totalEventCount']).to eq(0)
      end

      it 'defaults all event counts to 0' do
        response_node = ai_user_metrics['nodes'].first

        Gitlab::Tracking::AiTracking.registered_features.each do |feature|
          feature_key = feature.to_s.camelize(:lower)
          exposed_events_for(feature).each do |event|
            field_name = event_to_field_name(event)
            expect(response_node[feature_key][field_name]).to eq(0)
          end
        end
      end
    end

    context 'with date filtering' do
      context 'when no filter is provided' do
        let(:fields) { ['user { id }', 'totalEventCount'] }
        let(:expected_filters) { { from: Time.current.beginning_of_month, to: Time.current.end_of_month } }

        it 'uses current month as default' do
          expect(ai_user_metrics['nodes'].first['totalEventCount']).to be_a(Integer)
        end
      end

      context 'when filter range exceeds maximum' do
        let(:fields) { ['user { id }'] }
        let(:filter_params) { { startDate: 5.years.ago } }

        it 'returns an error' do
          expect_graphql_errors_to_include("maximum date range is 1 year")
          expect(ai_user_metrics).to be_nil
        end
      end
    end

    context 'with specific field queries' do
      context 'when querying lastDuoActivityOn' do
        let_it_be(:current_user_metrics) do
          create(:ai_user_metrics, last_duo_activity_on: 5.days.ago, user: current_user)
        end

        let(:fields) { ['user { id lastDuoActivityOn }'] }

        it 'returns the last activity date' do
          expect(ai_user_metrics['nodes'].first['user']['lastDuoActivityOn']).to eq(5.days.ago.to_date.to_s)
        end
      end

      context 'when querying only totalEventCount' do
        let(:fields) { ['totalEventCount', 'user { id }'] }
        let(:service_payload) { { current_user.id => { code_suggestion_accepted_in_ide_event_count: 10 } } }

        it 'returns the sum of all event counts' do
          expect(ai_user_metrics['nodes'].first['totalEventCount']).to eq(10)
        end
      end

      context 'when querying deprecated fields' do
        let(:fields) do
          [
            'user { id }',
            'codeSuggestionsAcceptedCount',
            'duoChatInteractionsCount',
            'codeSuggestions { codeSuggestionAcceptedInIdeEventCount }',
            'chat { requestDuoChatResponseEventCount }'
          ]
        end

        let(:service_payload) do
          {
            current_user.id => {
              code_suggestion_accepted_in_ide_event_count: 8,
              request_duo_chat_response_event_count: 3
            }
          }
        end

        it 'returns values for deprecated fields' do
          expect(ai_user_metrics['nodes'].first['codeSuggestionsAcceptedCount']).to eq(8)
          expect(ai_user_metrics['nodes'].first['duoChatInteractionsCount']).to eq(3)
        end

        it 'returns values for new fields' do
          expect(ai_user_metrics['nodes'].first['codeSuggestions']['codeSuggestionAcceptedInIdeEventCount']).to eq(8)
          expect(ai_user_metrics['nodes'].first['chat']['requestDuoChatResponseEventCount']).to eq(3)
        end
      end
    end
  end

  context 'for group' do
    it_behaves_like 'ai user metrics query' do
      let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_user_metrics_fields) }
      let(:ai_user_metrics) { graphql_data['group']['aiUserMetrics'] }
    end
  end

  context 'for project' do
    it_behaves_like 'ai user metrics query' do
      let(:query) { graphql_query_for(:project, { fullPath: project.full_path }, ai_user_metrics_fields) }
      let(:ai_user_metrics) { graphql_data['project']['aiUserMetrics'] }
    end
  end

  private

  def count_field_suffix
    Analytics::AiEventFields::COUNT_FIELD_SUFFIX
  end

  def event_to_field_name(event_name)
    "#{event_name.camelize(:lower)}#{count_field_suffix.camelize(:lower)}"
  end

  def exposed_events_for(feature)
    events = Gitlab::Tracking::AiTracking.registered_events(feature).keys
    allowed_events = Types::Analytics::AiUsage::AiUsageEventTypeEnum.values.each_value.map(&:value)
    exposed = events & allowed_events

    exposed.reject { |event| Gitlab::Tracking::AiTracking.deprecated_event?(event) }
  end

  def all_feature_fields
    Gitlab::Tracking::AiTracking.registered_features.map do |feature|
      events = exposed_events_for(feature)
      event_fields = events.map { |event| event_to_field_name(event) }.join(' ')

      "#{feature.to_s.camelize(:lower)} { #{event_fields} }"
    end
  end

  def all_feature_fields_with_total
    Gitlab::Tracking::AiTracking.registered_features.map do |feature|
      events = exposed_events_for(feature)
      event_fields = events.map { |event| event_to_field_name(event) }.join(' ')

      "#{feature.to_s.camelize(:lower)} { totalEventCount #{event_fields} }"
    end
  end

  def sample_event_counts
    @sample_event_counts ||= {}.tap do |payload|
      count = 1
      Gitlab::Tracking::AiTracking.registered_features.each do |feature|
        exposed_events_for(feature).each do |event|
          payload[:"#{event}#{count_field_suffix}"] = count
          count += 1
        end
      end
    end
  end
end
