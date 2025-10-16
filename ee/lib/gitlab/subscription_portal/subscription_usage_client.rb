# frozen_string_literal: true

module Gitlab
  module SubscriptionPortal
    class SubscriptionUsageClient < Client
      ResponseError = Class.new(StandardError)

      GET_METADATA_QUERY = <<~GQL
        query subscriptionUsage(
          $namespaceId: ID,
          $licenseKey: String
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage {
              startDate
              endDate
              lastUpdated
              purchaseCreditsPath
            }
          }
        }
      GQL

      GET_POOL_USAGE_QUERY = <<~GQL
        query subscriptionUsage(
          $namespaceId: ID,
          $licenseKey: String,
          $startDate: ISO8601Date,
          $endDate: ISO8601Date
        ) {
          subscription(namespaceId: $namespaceId, licenseKey: $licenseKey) {
            gitlabCreditsUsage(startDate: $startDate, endDate: $endDate) {
              poolUsage {
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
                  poolCreditsUsed
                  overageCreditsUsed
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

      def get_pool_usage
        response = execute_graphql_query(
          query: GET_POOL_USAGE_QUERY,
          variables: default_variables.merge(startDate: start_date, endDate: end_date)
        )

        if unsuccessful_response?(response)
          error(GET_POOL_USAGE_QUERY, response)
        else
          {
            success: true,
            poolUsage: response.dig(:data, :subscription, :gitlabCreditsUsage, :poolUsage)
          }
        end
      end

      def get_usage_for_user_ids(user_ids)
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
