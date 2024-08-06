# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying for Cloud Connector status', feature_category: :cloud_connector do
  include GraphqlHelpers

  let(:query) do
    graphql_query_for(:cloudConnectorStatus, {}, <<~FIELDS)
      success
      probeResults {
        name
        success
        message
      }
    FIELDS
  end

  before do
    # Need to stub this by default in order to allow expectations with specific
    # arguments in tests, as this method is called in various unrelated contexts.
    allow(::Gitlab::Saas).to receive(:feature_available?).and_call_original
  end

  context 'when the user is not authenticated' do
    it 'returns null' do
      post_graphql(query, current_user: nil)

      expect(graphql_data['cloudConnectorStatus']).to be_nil
    end
  end

  context 'when the user is authenticated' do
    let_it_be(:current_user) { create(:user) }

    let(:probe_results) { [CloudConnector::StatusChecks::Probes::ProbeResult.new('test_probe', true, 'probed')] }
    let(:service) { instance_double(CloudConnector::StatusChecks::StatusService, execute: service_response) }

    context 'when response is success' do
      let(:service_response) { ServiceResponse.success(message: 'OK', payload: { probe_results: probe_results }) }

      before do
        allow(CloudConnector::StatusChecks::StatusService).to receive(:new).and_return(service)
      end

      it 'returns successful status response' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data['cloudConnectorStatus']).to include(
          'success' => true,
          'probeResults' => match_array([{
            'name' => 'test_probe', 'success' => true, 'message' => 'probed'
          }])
        )
      end
    end

    context 'when response is error' do
      let(:service_response) { ServiceResponse.error(message: 'NOK', payload: { probe_results: probe_results }) }

      before do
        allow(CloudConnector::StatusChecks::StatusService).to receive(:new).and_return(service)
      end

      it 'returns unsuccessful status response' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data['cloudConnectorStatus']).to include(
          'success' => false,
          'probeResults' => match_array([{
            'name' => 'test_probe', 'success' => true, 'message' => 'probed'
          }])
        )
      end
    end

    context 'when cloud_connector_status feature flag is disabled' do
      before do
        stub_feature_flags(cloud_connector_status: false)
      end

      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data['cloudConnectorStatus']).to be_nil
      end
    end

    context 'when on gitlab.com' do
      before do
        allow(::Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
      end

      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data['cloudConnectorStatus']).to be_nil
      end
    end
  end
end
