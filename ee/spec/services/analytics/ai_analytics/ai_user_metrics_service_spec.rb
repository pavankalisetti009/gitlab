# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::AiUserMetricsService, feature_category: :value_stream_management do
  subject(:service_response) do
    described_class.new(
      current_user: current_user,
      namespace: container,
      from: from,
      to: to,
      user_ids: user_ids,
      feature: feature
    ).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:user1) { create(:user, developer_of: group) }
  let_it_be(:user2) { create(:user, developer_of: subgroup) }
  let_it_be(:current_user) { user1 }
  let_it_be(:from) { 14.days.ago }
  let_it_be(:to) { 1.day.ago }
  let_it_be(:user_ids) { [user1.id, user2.id] }
  let_it_be(:feature) { :code_suggestions }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'ai user metrics service' do
    context 'when ClickHouse is not available' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(container).and_return(false)
      end

      it 'returns error' do
        expect(service_response).to be_error
        expect(service_response.message).to eq(s_('AiAnalytics|the ClickHouse data store is not available'))
      end
    end

    context 'when feature has no registered events' do
      before do
        allow(Gitlab::Tracking::AiTracking).to receive(:registered_events).with(feature).and_return({})
      end

      it 'returns empty hash without querying ClickHouse' do
        expect(ClickHouse::Client).not_to receive(:select)
        expect(service_response).to be_success
        expect(service_response.payload).to eq({})
      end
    end

    context 'with ClickHouse available', :click_house, :freeze_time do
      context 'without data' do
        it 'returns empty hash' do
          expect(service_response).to be_success
          expect(service_response.payload).to eq({})
        end
      end

      context 'with code suggestions data' do
        let_it_be(:other_namespace) { create(:project).reload.project_namespace }
        let_it_be(:user3) { create(:user, developer_of: group) }

        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            { user_id: user1.id, namespace_path: container.traversal_path, event: 3,
              date: (to - 3.days).to_date, occurrences: 2 },
            { user_id: user1.id, namespace_path: container.traversal_path, event: 2,
              date: (to - 3.days).to_date, occurrences: 1 },
            { user_id: user1.id, namespace_path: other_namespace.traversal_path, event: 3,
              date: (to - 4.days).to_date, occurrences: 1 },
            { user_id: user2.id, namespace_path: container.traversal_path, event: 2,
              date: (to - 2.days).to_date, occurrences: 1 },
            { user_id: user2.id, namespace_path: other_namespace.traversal_path, event: 3,
              date: (to - 2.days).to_date, occurrences: 1 },
            { user_id: user3.id, namespace_path: container.traversal_path, event: 3,
              date: (to - 1.day).to_date, occurrences: 3 }
          ])
        end

        context 'when namespace filtering is disabled' do
          before do
            stub_feature_flags(use_ai_events_namespace_path_filter: false)
          end

          it 'returns all events for specified users across all namespaces' do
            expect(service_response).to be_success
            expect(service_response.payload).to match({
              user1.id => {
                code_suggestion_accepted_in_ide_event_count: 3,
                code_suggestion_shown_in_ide_event_count: 1
              },
              user2.id => {
                code_suggestion_accepted_in_ide_event_count: 1,
                code_suggestion_shown_in_ide_event_count: 1
              }
            })
          end
        end

        context 'when namespace filtering is enabled' do
          it 'returns only events within the specified namespace' do
            expect(service_response).to be_success
            expect(service_response.payload).to match({
              user1.id => {
                code_suggestion_accepted_in_ide_event_count: 2,
                code_suggestion_shown_in_ide_event_count: 1
              },
              user2.id => {
                code_suggestion_shown_in_ide_event_count: 1
              }
            })
          end
        end

        context 'when user_ids is empty' do
          let(:user_ids) { [] }

          it 'returns metrics for all users without filtering by user_ids' do
            expect(service_response).to be_success
            expect(service_response.payload).to match({
              user1.id => {
                code_suggestion_accepted_in_ide_event_count: 2,
                code_suggestion_shown_in_ide_event_count: 1
              },
              user2.id => {
                code_suggestion_shown_in_ide_event_count: 1
              },
              user3.id => {
                code_suggestion_accepted_in_ide_event_count: 3
              }
            })
          end
        end

        context 'when user_ids is nil' do
          let(:user_ids) { nil }

          it 'returns metrics for all users without filtering by user_ids' do
            expect(service_response).to be_success
            expect(service_response.payload).to match({
              user1.id => {
                code_suggestion_accepted_in_ide_event_count: 2,
                code_suggestion_shown_in_ide_event_count: 1
              },
              user2.id => {
                code_suggestion_shown_in_ide_event_count: 1
              },
              user3.id => {
                code_suggestion_accepted_in_ide_event_count: 3
              }
            })
          end
        end

        context 'when user_ids has specific values' do
          let(:user_ids) { [user1.id] }

          it 'returns metrics only for specified users' do
            expect(service_response).to be_success
            expect(service_response.payload).to match({
              user1.id => {
                code_suggestion_accepted_in_ide_event_count: 2,
                code_suggestion_shown_in_ide_event_count: 1
              }
            })
          end
        end
      end

      context 'with chat data' do
        let(:feature) { :chat }
        let_it_be(:other_namespace) { create(:project).reload.project_namespace }

        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            { user_id: user1.id, namespace_path: container.traversal_path, event: 6,
              date: (to - 3.days).to_date, occurrences: 2 },
            { user_id: user1.id, namespace_path: other_namespace.traversal_path, event: 6,
              date: (to - 3.days).to_date, occurrences: 1 },
            { user_id: user2.id, namespace_path: container.traversal_path, event: 6,
              date: (to - 2.days).to_date, occurrences: 1 }
          ])
        end

        context 'when namespace filtering is disabled' do
          before do
            stub_feature_flags(use_ai_events_namespace_path_filter: false)
          end

          it 'returns chat metrics across all namespaces' do
            expect(service_response).to be_success
            expect(service_response.payload).to match({
              user1.id => { request_duo_chat_response_event_count: 3 },
              user2.id => { request_duo_chat_response_event_count: 1 }
            })
          end
        end

        context 'when namespace filtering is enabled' do
          it 'returns chat metrics only within the specified namespace' do
            expect(service_response).to be_success
            expect(service_response.payload).to match({
              user1.id => { request_duo_chat_response_event_count: 2 },
              user2.id => { request_duo_chat_response_event_count: 1 }
            })
          end
        end
      end

      context 'when ClickHouse returns unknown event IDs' do
        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            { user_id: user1.id, namespace_path: container.traversal_path, event: 3,
              date: (to - 3.days).to_date, occurrences: 2 },
            { user_id: user1.id, namespace_path: container.traversal_path, event: 999,
              date: (to - 3.days).to_date, occurrences: 5 },
            { user_id: user2.id, namespace_path: container.traversal_path, event: 2,
              date: (to - 2.days).to_date, occurrences: 1 }
          ])
        end

        it 'skips events that cannot be mapped to event names' do
          expect(service_response).to be_success
          expect(service_response.payload).to match({
            user1.id => { code_suggestion_accepted_in_ide_event_count: 2 },
            user2.id => { code_suggestion_shown_in_ide_event_count: 1 }
          })
        end
      end
    end
  end

  context 'for group namespace' do
    let(:container) { group }

    it_behaves_like 'ai user metrics service'
  end

  context 'for project namespace' do
    let(:container) { project.project_namespace.reload }

    it_behaves_like 'ai user metrics service'
  end
end
