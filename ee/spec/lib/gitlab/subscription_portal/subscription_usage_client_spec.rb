# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::SubscriptionUsageClient, feature_category: :consumables_cost_management do
  let(:graphql_url) { ::Gitlab::Routing.url_helpers.subscription_portal_graphql_url }
  let(:start_date) { Date.current.beginning_of_month }
  let(:end_date) { Date.current.end_of_month }
  let(:params) do
    { query: query, variables: variables }
  end

  let(:headers) do
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "User-Agent" => "GitLab/#{Gitlab::VERSION}"
    }.merge(admin_headers || {})
  end

  subject(:client) do
    described_class.new(
      namespace_id: namespace_id,
      license_key: license_key
    )
  end

  shared_examples 'performs request with correct params' do
    it 'perform post request with correct params' do
      expect(::Gitlab::HTTP).to receive(:post).with(
        graphql_url,
        headers: headers,
        body: params.to_json
      ).and_return(instance_double(
        HTTParty::Response,
        response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
        parsed_response: portal_response
      ))

      request
    end
  end

  shared_examples 'returns successfully' do
    it 'returns a successful response' do
      expect(::Gitlab::HTTP).to receive(:post).with(
        graphql_url,
        headers: headers,
        body: params.to_json
      ).and_return(instance_double(
        HTTParty::Response,
        response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
        parsed_response: portal_response
      ))

      expect(request).to eq(expected_response)
    end
  end

  shared_examples 'returns error on unsuccessful subscription portal response' do
    it 'logs and returns error from subscription portal' do
      response = instance_double(
        HTTParty::Response,
        response: Net::HTTPSuccess.new(1.0, '200', 'OK'),
        parsed_response: {
          success: false,
          data: {
            errors: 'some error'
          }
        }
      )

      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
        a_kind_of(described_class::ResponseError),
        query: query,
        response: response.parsed_response
      )

      expect(::Gitlab::HTTP).to receive(:post).with(
        graphql_url,
        headers: headers,
        body: params.to_json
      ).and_return(response)

      expect(request).to eq({ success: false, errors: 'some error' })
    end

    it 'logs and returns error when subscription portal is not available' do
      http_response = instance_double(
        HTTParty::Response,
        response: Net::HTTPServiceUnavailable.new(1.0, '503', 'Service Unavailable')
      )

      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
        a_kind_of(described_class::ResponseError),
        query: query,
        response: { data: { errors: 'Service Unavailable' } }
      )

      expect(::Gitlab::HTTP).to receive(:post).with(
        graphql_url,
        headers: headers,
        body: params.to_json
      ).and_return(http_response)

      expect(request).to eq({ success: false, errors: 'Service Unavailable' })
    end
  end

  before do
    stub_env('GITLAB_QA_USER_AGENT', nil)
  end

  shared_context 'for self-managed request' do
    let(:admin_headers) { nil }
    let(:namespace_id) { nil }
    let(:license_key) { 'license_key' }

    include_examples 'performs request with correct params'
    include_examples 'returns successfully'
    include_examples 'returns error on unsuccessful subscription portal response'
  end

  shared_context 'for gitlab.com request' do
    let(:namespace_id) { 1234 }
    let(:license_key) { nil }
    let(:admin_headers) do
      {
        "X-Admin-Email" => "gl_com_api@gitlab.com",
        "X-Admin-Token" => "customer_admin_token"
      }
    end

    include_examples 'performs request with correct params'
    include_examples 'returns successfully'
    include_examples 'returns error on unsuccessful subscription portal response'
  end

  describe '#get_metadata' do
    context 'when the subscription portal response is successful' do
      let(:request) { client.get_metadata }
      let(:query) { described_class::GET_METADATA_QUERY }
      let(:portal_response) do
        {
          success: true,
          data: {
            subscription: {
              gitlabCreditsUsage: {
                startDate: "2025-10-01",
                endDate: "2025-10-31",
                lastUpdated: "2025-10-01T16:19:59Z",
                purchaseCreditsPath: '/mock/path'
              }
            }
          }
        }
      end

      let(:expected_response) do
        {
          success: true,
          subscriptionUsage: {
            startDate: "2025-10-01",
            endDate: "2025-10-31",
            lastUpdated: "2025-10-01T16:19:59Z",
            purchaseCreditsPath: '/mock/path'
          }
        }
      end

      include_context 'for self-managed request' do
        let(:variables) { { licenseKey: license_key } }
      end

      include_context 'for gitlab.com request' do
        let(:variables) { { namespaceId: namespace_id } }
      end
    end
  end

  describe '#get_pool_usage' do
    context 'when the subscription portal response is successful' do
      let(:request) { client.get_pool_usage }
      let(:query) { described_class::GET_POOL_USAGE_QUERY }
      let(:pool_usage) do
        {
          totalCredits: 1000,
          creditsUsed: 250,
          dailyUsage: [{ date: '2025-10-01', creditsUsed: 250 }]
        }
      end

      let(:portal_response) do
        {
          success: true,
          data: {
            subscription: {
              gitlabCreditsUsage: {
                poolUsage: pool_usage
              }
            }
          }
        }
      end

      let(:expected_response) do
        {
          success: true,
          poolUsage: pool_usage
        }
      end

      include_context 'for self-managed request' do
        let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
      end

      include_context 'for gitlab.com request' do
        let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
      end
    end
  end

  describe '#get_overage_usage' do
    context 'when the subscription portal response is successful' do
      let(:request) { client.get_overage_usage }
      let(:query) { described_class::GET_OVERAGE_USAGE_QUERY }
      let(:overage) do
        {
          isAllowed: true,
          creditsUsed: 250,
          dailyUsage: [{ date: '2025-10-01', creditsUsed: 250 }]
        }
      end

      let(:portal_response) do
        {
          success: true,
          data: {
            subscription: {
              gitlabCreditsUsage: {
                overage: overage
              }
            }
          }
        }
      end

      let(:expected_response) do
        {
          success: true,
          overage: overage
        }
      end

      include_context 'for self-managed request' do
        let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
      end

      include_context 'for gitlab.com request' do
        let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
      end
    end
  end

  describe '#get_usage_for_user_ids' do
    context 'when the subscription portal response is successful' do
      let(:user_ids) { [123, 321] }
      let(:request) { client.get_usage_for_user_ids(user_ids) }
      let(:query) { described_class::GET_USERS_USAGE_QUERY }
      let(:users_usage) do
        [
          {
            userId: 123,
            totalCredits: 100,
            creditsUsed: 500,
            poolCreditsUsed: 400,
            overageCreditsUsed: 50
          },
          {
            userId: 321,
            totalCredits: 100,
            creditsUsed: 50,
            poolCreditsUsed: 0,
            overageCreditsUsed: 0
          }
        ]
      end

      let(:portal_response) do
        {
          success: true,
          data: {
            subscription: {
              gitlabCreditsUsage: {
                usersUsage: { users: users_usage }
              }
            }
          }
        }
      end

      let(:expected_response) do
        {
          success: true,
          usersUsage: users_usage
        }
      end

      include_context 'for self-managed request' do
        let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date, userIds: user_ids } }
      end

      include_context 'for gitlab.com request' do
        let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date, userIds: user_ids } }
      end
    end
  end

  describe '#get_users_usage_stats' do
    context 'when the subscription portal response is successful' do
      let(:request) { client.get_users_usage_stats }
      let(:query) { described_class::GET_USERS_USAGE_STATS_QUERY }
      let(:portal_response) do
        {
          success: true,
          data: {
            subscription: {
              gitlabCreditsUsage: {
                usersUsage: {
                  totalUsersUsingCredits: 3,
                  totalUsersUsingPool: 2,
                  totalUsersUsingOverage: 1,
                  dailyUsage: [{ date: '2025-10-01', creditsUsed: 321 }]
                }
              }
            }
          }
        }
      end

      let(:expected_response) do
        {
          success: true,
          usersUsage: {
            totalUsersUsingCredits: 3,
            totalUsersUsingPool: 2,
            totalUsersUsingOverage: 1,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 321 }]
          }
        }
      end

      include_context 'for self-managed request' do
        let(:variables) { { licenseKey: license_key, startDate: start_date, endDate: end_date } }
      end

      include_context 'for gitlab.com request' do
        let(:variables) { { namespaceId: namespace_id, startDate: start_date, endDate: end_date } }
      end
    end
  end
end
