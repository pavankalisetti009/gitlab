# frozen_string_literal: true

module Jira
  module Requests
    module Issues
      class ListService < Base
        extend ::Gitlab::Utils::Override

        PER_PAGE = 100
        DEFAULT_FIELDS = %w[assignee created creator id issuetype key
          labels priority project reporter resolutiondate
          status statuscategorychangeddate summary updated].join(',').freeze

        def initialize(jira_integration, params = {})
          super(jira_integration, params)

          @jql = params[:jql].to_s
          @next_page_token = params[:next_page_token]
          @per_page = (params[:per_page] || PER_PAGE).to_i
        end

        private

        attr_reader :jql, :next_page_token, :per_page

        override :api_version
        def api_version
          3
        end

        override :url
        def url
          base_url = "#{base_api_url}/search/jql?jql=#{CGI.escape(jql)}&maxResults=#{per_page}&fields=#{DEFAULT_FIELDS}"

          if next_page_token.present?
            "#{base_url}&nextPageToken=#{CGI.escape(next_page_token)}"
          else
            base_url
          end
        end

        override :build_service_response
        def build_service_response(response)
          return ServiceResponse.success(payload: empty_payload) if response.blank? || response["issues"].blank?

          ServiceResponse.success(payload: {
            issues: map_issues(response["issues"]),
            is_last: response["isLast"] || false,
            next_page_token: response["nextPageToken"]
          })
        end

        def map_issues(response)
          response.map { |v| JIRA::Resource::Issue.build(client, v) }
        end

        def empty_payload
          { issues: [], is_last: true, next_page_token: nil }
        end
      end
    end
  end
end
