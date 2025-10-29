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

      GET_ONE_TIME_CREDITS_QUERY = <<~GQL
        query subscriptionUsageOneTimeCredits(
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(startDate: $startDate, endDate: $endDate) {
              oneTimeCredits {
                creditsUsed
                totalCredits
                totalCreditsRemaining
              }
            }
          }
        }
      GQL

      GET_MONTHLY_COMMITMENT_QUERY = <<~GQL
        query subscriptionUsageMonthlyCommitment(
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(startDate: $startDate, endDate: $endDate) {
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
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(startDate: $startDate, endDate: $endDate) {
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
          $userIds: [Int!]!,
          $page: Int,
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(startDate: $startDate, endDate:$endDate) {
              usersUsage {
                users(userIds: $userIds) {
                  events(page: $page) {
                    timestamp
                    eventType
                    projectId
                    namespaceId
                    creditsUsed
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
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(startDate: $startDate, endDate:$endDate) {
              usersUsage {
                users(userIds: $userIds) {
                  userId
                  totalCredits
                  creditsUsed
                  monthlyCommitmentCreditsUsed
                  oneTimeCreditsUsed
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
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(startDate: $startDate, endDate:$endDate) {
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
      # @param start_date [Date] The start date for the usage data. Defaults to the beginning of the current month.
      # @param end_date [Date] The end date for the usage data. Defaults to the end of the current month.
      # @param namespace_id [Integer] The ID of the namespace, used when in GitLab.com
      # @param license_key [String] The license key to use for authentication in Self-Managed instances
      def initialize(
        start_date: Date.current.beginning_of_month,
        end_date: Date.current.end_of_month,
        namespace_id: nil,
        license_key: nil
      )
        @start_date = start_date
        @end_date = end_date
        @namespace_id = namespace_id
        @license_key = license_key
      end

      def get_metadata
        response = execute_graphql_query(
          query: GET_METADATA_QUERY,
          variables: default_variables
        )

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

      def get_one_time_credits
        response = execute_graphql_query(
          query: GET_ONE_TIME_CREDITS_QUERY,
          variables: default_variables.merge(startDate: start_date, endDate: end_date)
        )

        if unsuccessful_response?(response)
          error(GET_ONE_TIME_CREDITS_QUERY, response)
        else
          {
            success: true,
            oneTimeCredits: response.dig(:data, :subscription, :gitlabCreditsUsage, :oneTimeCredits)
          }
        end
      end

      def get_monthly_commitment
        response = execute_graphql_query(
          query: GET_MONTHLY_COMMITMENT_QUERY,
          variables: default_variables.merge(startDate: start_date, endDate: end_date)
        )

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
        response = execute_graphql_query(
          query: GET_OVERAGE_QUERY,
          variables: default_variables.merge(startDate: start_date, endDate: end_date)
        )

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

      def get_events_for_user_id(user_id, page)
        strong_memoize_with(:get_events_for_user_id, user_id, page) do
          response = execute_graphql_query(
            query: GET_USER_EVENTS_QUERY,
            variables: default_variables.merge(startDate: start_date, endDate: end_date, userIds: [user_id], page: page)
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
          response = execute_graphql_query(
            query: GET_USERS_USAGE_QUERY,
            variables: default_variables.merge(startDate: start_date, endDate: end_date, userIds: user_ids)
          )

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
        response = execute_graphql_query(
          query: GET_USERS_USAGE_STATS_QUERY,
          variables: default_variables.merge(startDate: start_date, endDate: end_date)
        )

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

      attr_reader :start_date, :end_date, :namespace_id, :license_key

      private

      def execute_graphql_query(params)
        headers = params.dig(:variables, :licenseKey) ? json_headers : admin_headers

        http_response = ::Gitlab::HTTP.post(
          ::Gitlab::Routing.url_helpers.subscription_portal_graphql_url,
          headers: headers,
          body: params.to_json
        )

        if http_response.response.is_a?(Net::HTTPSuccess)
          http_response.parsed_response.deep_symbolize_keys
        else
          { data: { errors: http_response.response.message } }
        end
      end

      def default_variables
        {
          namespaceId: namespace_id,
          licenseKey: license_key
        }.compact
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
