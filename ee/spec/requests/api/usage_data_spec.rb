# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::UsageData, feature_category: :service_ping do
  let_it_be(:user) { create(:user) }

  describe 'POST /usage_data/track_event' do
    let(:endpoint) { '/usage_data/track_event' }
    let(:event_name) { 'code_suggestion_shown_in_ide' }
    let(:project) { nil }
    let(:namespace) { nil }

    let(:additional_properties) do
      {
        language: 'ruby',
        timestamp: '2024-01-01',
        suggestion_size: '100',
        branch_name: 'foo'
      }
    end

    let(:identifiers) do
      {
        user: user,
        project_id: project&.id,
        namespace_id: namespace&.id
      }
    end

    let(:allowed_fields_for_snowplow) do
      identifiers.merge(additional_properties).except(:branch_name).symbolize_keys
    end

    before do
      stub_application_setting(usage_ping_enabled: true, use_clickhouse_for_analytics: true)
    end

    def expect_track_events
      expect(Gitlab::InternalEvents).to receive(:track_event)
        .with(
          event_name,
          additional_properties: additional_properties,
          project: project,
          namespace: namespace,
          user: user,
          send_snowplow_event: false
        ).and_call_original

      # rubocop:disable RSpec/ExpectGitlabTracking -- Need to verify Snowplow params directly here
      expect(Gitlab::Tracking).not_to receive(:event).with(anything, event_name, anything)
      # rubocop:enable RSpec/ExpectGitlabTracking

      expect(Gitlab::Tracking::AiTracking).to receive(:track_event)
        .with(
          event_name,
          additional_properties.merge({
            project: project,
            namespace: namespace,
            user: user
          })
        )
        .and_call_original
    end

    def make_request
      post api(endpoint, user), params: {
        event: event_name,
        project_id: project&.id,
        namespace_id: namespace&.id,
        additional_properties: additional_properties
      }
    end

    context 'with AI related metric' do
      it 'triggers AI tracking without project or namespace' do
        expect_track_events
        make_request
        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when project is passed' do
        let_it_be(:project) { create(:project) }

        it 'triggers AI tracking with project' do
          expect_track_events
          make_request
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when namespace is passed' do
        let_it_be(:namespace) { create(:namespace) }

        it 'triggers AI tracking with namespace' do
          expect_track_events
          make_request
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when both project and namespace are passed' do
        let_it_be(:project) { create(:project) }
        let_it_be(:namespace) { create(:namespace) }

        it 'triggers AI tracking with both project and namespace' do
          expect_track_events
          make_request
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end
end
