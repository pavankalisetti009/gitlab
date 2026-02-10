# frozen_string_literal: true

module VirtualRegistries
  module Upstreams
    module Remote
      class RedirectHandler
        MAX_REDIRECTS = 5
        REDIRECT_STATUS_CODES = [301, 302, 303, 307, 308].freeze

        def initialize(headers:, timeout:, redirect_count: 0)
          @headers = headers
          @timeout = timeout
          @redirect_count = redirect_count
        end

        def redirect?(response)
          REDIRECT_STATUS_CODES.include?(response.code)
        end

        def build_follow_request(response, &on_complete)
          return if max_redirects_exceeded?

          url = redirect_url(response)
          return unless url
          return unless valid_url?(url)

          build_request(url, &on_complete)
        end

        private

        attr_reader :headers, :timeout, :redirect_count

        def redirect_url(response)
          response.headers&.dig('Location')
        end

        def max_redirects_exceeded?
          redirect_count >= MAX_REDIRECTS
        end

        def valid_url?(url)
          validate_url!(url)
          true
        rescue Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError
          false
        end

        def validate_url!(url)
          Gitlab::HTTP_V2::UrlBlocker.validate!(
            url,
            schemes: %w[http https],
            allow_localhost: false,
            allow_local_network: false,
            dns_rebind_protection: true
          )
        end

        def build_request(url)
          request = Typhoeus::Request.new(
            url,
            headers: headers,
            method: :head,
            followlocation: false,
            timeout: timeout
          )

          next_handler = self.class.new(
            headers: headers,
            timeout: timeout,
            redirect_count: redirect_count + 1
          )

          request.on_complete do |follow_response|
            yield(follow_response, next_handler)
          end

          request
        end
      end
    end
  end
end
