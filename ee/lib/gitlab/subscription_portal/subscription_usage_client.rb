# frozen_string_literal: true

module Gitlab
  module SubscriptionPortal
    class SubscriptionUsageClient < Client
      include ::Gitlab::Utils::StrongMemoize

      ResponseError = Class.new(StandardError)

      GET_METADATA_QUERY = <<~GQL
        query subscriptionUsageMetadata(
          $namespaceId: ID,
          $licenseKey: String
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage {
              startDate
              endDate
              lastEventTransactionAt
              purchaseCreditsPath
            }
          }
        }
      GQL

      GET_MONTHLY_WAIVER_QUERY = <<~GQL
        query subscriptionUsageMonthlyWaiver(
          $namespaceId: ID,
          $licenseKey: String
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage {
              monthlyWaiver {
                creditsUsed
                totalCredits
              }
            }
          }
        }
      GQL

      GET_MONTHLY_COMMITMENT_QUERY = <<~GQL
        query subscriptionUsageMonthlyCommitment(
          $namespaceId: ID,
          $licenseKey: String
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage {
              monthlyCommitment {
                totalCredits
                creditsUsed
                dailyUsage {
                  date
                  creditsUsed
                }
              }
            }
          }
        }
      GQL

      GET_OVERAGE_QUERY = <<~GQL
        query subscriptionUsageOverage(
          $namespaceId: ID,
          $licenseKey: String
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage {
              overage {
                isAllowed
                creditsUsed
                dailyUsage {
                  date
                  creditsUsed
                }
              }
            }
          }
        }
      GQL

      GET_USER_EVENTS_QUERY = <<~GQL
        query subscriptionUsageUserEvents(
          $namespaceId: ID,
          $licenseKey: String,
          $userIds: [Int!]!,
          $after: ISO8601DateTime,
          $before: ISO8601DateTime
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage {
              usersUsage {
                users(userIds: $userIds) {
                  events(after: $after, before: $before) {
                    nodes {
                      timestamp
                      eventType
                      projectId
                      namespaceId
                      creditsUsed
                    }
                    pageInfo {
                      hasNextPage
                      hasPreviousPage
                      startCursor
                      endCursor
                    }
                  }
                }
              }
            }
          }
        }
      GQL

      GET_USERS_USAGE_QUERY = <<~GQL
        query subscriptionUsageForUserIds(
          $userIds: [Int!]!,
          $namespaceId: ID,
          $licenseKey: String
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage {
              usersUsage {
                users(userIds: $userIds) {
                  userId
                  totalCredits
                  creditsUsed
                  monthlyCommitmentCreditsUsed
                  monthlyWaiverCreditsUsed
                  overageCreditsUsed
                }
              }
            }
          }
        }
      GQL

      GET_USERS_USAGE_STATS_QUERY = <<~GQL
        query subscriptionUsageUsersStats(
          $namespaceId: ID,
          $licenseKey: String
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage {
              usersUsage {
                totalUsersUsingCredits
                totalUsersUsingMonthlyCommitment
                totalUsersUsingOverage
                creditsUsed
                dailyUsage {
                  date
                  creditsUsed
                }
              }
            }
          }
        }
      GQL

      # Initialize the client with the provided parameters that will be used later
      # to make API calls to the subscription portal
      #
      # @param namespace_id [Integer] The ID of the namespace, used when in GitLab.com
      # @param license_key [String] The license key to use for authentication in Self-Managed instances
      def initialize(namespace_id: nil, license_key: nil)
        @namespace_id = namespace_id
        @license_key = license_key
      end

      def get_metadata
        response = execute_graphql_query(query: GET_METADATA_QUERY)

        if unsuccessful_response?(response)
          error(GET_METADATA_QUERY, response)
        else
          {
            success: true,
            subscriptionUsage: response.dig(:data, :subscription, :gitlabCreditsUsage)
          }
        end
      end
      strong_memoize_attr :get_metadata

      def get_monthly_waiver
        response = execute_graphql_query(query: GET_MONTHLY_WAIVER_QUERY)

        if unsuccessful_response?(response)
          error(GET_MONTHLY_WAIVER_QUERY, response)
        else
          {
            success: true,
            monthlyWaiver: response.dig(:data, :subscription, :gitlabCreditsUsage, :monthlyWaiver)
          }
        end
      end

      def get_monthly_commitment
        response = execute_graphql_query(query: GET_MONTHLY_COMMITMENT_QUERY)

        if unsuccessful_response?(response)
          error(GET_MONTHLY_COMMITMENT_QUERY, response)
        else
          {
            success: true,
            monthlyCommitment: response.dig(:data, :subscription, :gitlabCreditsUsage, :monthlyCommitment)
          }
        end
      end
      strong_memoize_attr :get_monthly_commitment

      def get_overage
        response = execute_graphql_query(query: GET_OVERAGE_QUERY)

        if unsuccessful_response?(response)
          error(GET_OVERAGE_QUERY, response)
        else
          {
            success: true,
            overage: response.dig(:data, :subscription, :gitlabCreditsUsage, :overage)
          }
        end
      end
      strong_memoize_attr :get_overage

      def get_events_for_user_id(user_id, args)
        strong_memoize_with(:get_events_for_user_id, user_id, args) do
          response = execute_graphql_query(
            query: GET_USER_EVENTS_QUERY,
            extra_variables: {
              userIds: [user_id],
              before: args[:before],
              after: args[:after]
            }
          )

          if unsuccessful_response?(response)
            error(GET_USER_EVENTS_QUERY, response)
          else
            user_events = response.dig(:data, :subscription, :gitlabCreditsUsage, :usersUsage, :users)
              .to_a.first&.fetch(:events)
            {
              success: true,
              userEvents: user_events
            }
          end
        end
      end

      def get_usage_for_user_ids(user_ids)
        strong_memoize_with(:get_usage_for_user_ids, user_ids) do
          response = execute_graphql_query(query: GET_USERS_USAGE_QUERY, extra_variables: { userIds: user_ids })

          if unsuccessful_response?(response)
            error(GET_USERS_USAGE_QUERY, response)
          else
            {
              success: true,
              usersUsage: response.dig(:data, :subscription, :gitlabCreditsUsage, :usersUsage, :users)
            }
          end
        end
      end

      def get_users_usage_stats
        response = execute_graphql_query(query: GET_USERS_USAGE_STATS_QUERY)

        if unsuccessful_response?(response)
          error(GET_USERS_USAGE_STATS_QUERY, response)
        else
          {
            success: true,
            usersUsage: response.dig(:data, :subscription, :gitlabCreditsUsage, :usersUsage)
          }
        end
      end
      strong_memoize_attr :get_users_usage_stats

      attr_reader :namespace_id, :license_key

      private

      def execute_graphql_query(query:, extra_variables: {})
        variables = {
          namespaceId: namespace_id,
          licenseKey: license_key
        }.compact.merge(extra_variables)

        headers = variables[:licenseKey] ? json_headers : admin_headers

        http_response = ::Gitlab::HTTP.post(
          ::Gitlab::Routing.url_helpers.subscription_portal_graphql_url,
          headers: headers,
          body: { query: query, variables: variables }.to_json
        )

        if http_response.response.is_a?(Net::HTTPSuccess)
          http_response.parsed_response.deep_symbolize_keys
        else
          { data: { errors: http_response.response.message } }
        end
      end

      def unsuccessful_response?(response)
        return if response.dig(:data, :errors).blank?

        true
      end

      def error(query, response)
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
          ResponseError.new("Received an error from CustomerDot"),
          query: query,
          response: response
        )

        {
          success: false,
          errors: response.dig(:data, :errors)
        }
      end

      def default_headers
        {
          "User-Agent" => Gitlab::Qa.user_agent.presence || "GitLab/#{Gitlab::VERSION}"
        }
      end

      def json_headers
        default_headers.merge(
          {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          }
        )
      end

      def admin_headers
        json_headers.merge(
          {
            'X-Admin-Email' => Gitlab::SubscriptionPortal::SUBSCRIPTION_PORTAL_ADMIN_EMAIL,
            'X-Admin-Token' => Gitlab::SubscriptionPortal::SUBSCRIPTION_PORTAL_ADMIN_TOKEN
          }
        )
      end
    end
  end
end
