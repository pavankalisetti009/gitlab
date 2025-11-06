# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::SubscriptionUsageClient, feature_category: :consumables_cost_management do
  let(:graphql_url) { ::Gitlab::Routing.url_helpers.subscription_portal_graphql_url }
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
              lastEventTransactionAt: "2025-10-01T16:19:59Z",
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
          lastEventTransactionAt: "2025-10-01T16:19:59Z",
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

  describe '#get_monthly_waiver' do
    let(:request) { client.get_monthly_waiver }
    let(:query) { described_class::GET_MONTHLY_WAIVER_QUERY }
    let(:monthly_waiver) do
      {
        creditsUsed: 12.25,
        totalCredits: 1000.91
      }
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              monthlyWaiver: monthly_waiver
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        monthlyWaiver: monthly_waiver
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id } }
    end
  end

  describe '#get_monthly_commitment' do
    let(:request) { client.get_monthly_commitment }
    let(:query) { described_class::GET_MONTHLY_COMMITMENT_QUERY }
    let(:monthly_commitment) do
      {
        totalCredits: 1000.91,
        creditsUsed: 250.32,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 250.32 }]
      }
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              monthlyCommitment: monthly_commitment
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        monthlyCommitment: monthly_commitment
      }
    end

    include_context 'for self-managed request' do
      let(:variables) { { licenseKey: license_key } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id } }
    end
  end

  describe '#get_overage' do
    let(:request) { client.get_overage }
    let(:query) { described_class::GET_OVERAGE_QUERY }
    let(:overage) do
      {
        isAllowed: true,
        creditsUsed: 250.32,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 250.32 }]
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
      let(:variables) { { licenseKey: license_key } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id } }
    end
  end

  describe '#get_events_for_user_id' do
    let(:user_id) { 123 }
    let(:args) { { before: nil, after: nil } }
    let(:request) { client.get_events_for_user_id(user_id, args) }
    let(:query) { described_class::GET_USER_EVENTS_QUERY }
    let(:user_events) do
      [
        {
          timestamp: "2025-10-01T16:25:28Z",
          eventType: "ai_token_usage",
          projectId: nil,
          namespaceId: nil,
          creditsUsed: 100.78
        },
        {
          timestamp: "2025-10-01T16:30:12Z",
          eventType: "workflow_execution",
          projectId: "19",
          namespaceId: "99",
          creditsUsed: 200.56
        }
      ]
    end

    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              usersUsage: {
                users: [{
                  events: {
                    nodes: user_events,
                    pageInfo: {
                      hasNextPage: false,
                      hasPreviousPage: false,
                      startCursor: "2025-10-01T16:25:28Z",
                      endCursor: "2025-10-01T16:30:12Z"
                    }
                  }
                }]
              }
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        userEvents: {
          nodes: user_events,
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: "2025-10-01T16:25:28Z",
            endCursor: "2025-10-01T16:30:12Z"
          }
        }
      }
    end

    include_context 'for self-managed request' do
      let(:variables) do
        { licenseKey: license_key, userIds: [user_id], **args }
      end
    end

    include_context 'for gitlab.com request' do
      let(:variables) do
        { namespaceId: namespace_id, userIds: [user_id], **args }
      end
    end
  end

  describe '#get_usage_for_user_ids' do
    let(:user_ids) { [123, 321] }
    let(:request) { client.get_usage_for_user_ids(user_ids) }
    let(:query) { described_class::GET_USERS_USAGE_QUERY }
    let(:users_usage) do
      [
        {
          userId: 123,
          totalCredits: 100.12,
          creditsUsed: 500.23,
          monthlyCommitmentCreditsUsed: 400.45,
          monthlyWaiverCreditsUsed: 25.56,
          overageCreditsUsed: 50.67
        },
        {
          userId: 321,
          totalCredits: 100.12,
          creditsUsed: 50.23,
          monthlyCommitmentCreditsUsed: 0,
          monthlyWaiverCreditsUsed: 12.34,
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
      let(:variables) { { licenseKey: license_key, userIds: user_ids } }
    end

    include_context 'for gitlab.com request' do
      let(:variables) { { namespaceId: namespace_id, userIds: user_ids } }
    end
  end

  describe '#get_users_usage_stats' do
    let(:request) { client.get_users_usage_stats }
    let(:query) { described_class::GET_USERS_USAGE_STATS_QUERY }
    let(:portal_response) do
      {
        success: true,
        data: {
          subscription: {
            gitlabCreditsUsage: {
              usersUsage: {
                totalUsersUsingCredits: 9.87,
                totalUsersUsingMonthlyCommitment: 8.76,
                totalUsersUsingOverage: 6.54,
                creditsUsed: 123.45,
                dailyUsage: [{ date: '2025-10-01', creditsUsed: 123.45 }]
              }
            }
          }
        }
      }
    end

    let(:expected_response) do
      {
        success: true,
        usersUsage: portal_response[:data][:subscription][:gitlabCreditsUsage][:usersUsage]
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
