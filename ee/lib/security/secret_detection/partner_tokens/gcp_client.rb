# frozen_string_literal: true

module Security
  module SecretDetection
    module PartnerTokens
      class GcpClient < BaseClient
        TOKENINFO_ENDPOINT = 'https://oauth2.googleapis.com/tokeninfo'

        private

        def valid_format?(token_value)
          # Match GCP token patterns based on secret detection rules
          # Ref: https://gitlab.com/gitlab-org/security-products/secret-detection/secret-detection-rules/-/blob/main/rules/mit/gcp/gcp.toml
          return false unless token_value

          # GCP API Key pattern: AIza[0-9A-Za-z_-]{35}
          # GCP OAuth Access Token pattern: ya29.[0-9A-Za-z_-]{100,}
          # GCP Client Secret pattern: [0-9A-Za-z_-]{24,}
          gcp_api_key_pattern = /\AAIza[0-9A-Za-z_-]{35}\z/
          gcp_access_token_pattern = /\Aya29\.[0-9A-Za-z_-]{100,}\z/
          gcp_client_secret_pattern = /\A[0-9A-Za-z_-]{24,}\z/

          token_value.match?(gcp_api_key_pattern) ||
            token_value.match?(gcp_access_token_pattern) ||
            token_value.match?(gcp_client_secret_pattern)
        end

        # GCP OAuth2 tokeninfo endpoint approach:
        # Send access token as query parameter to validate its status
        # - Valid token: 200 response with token details
        # - Invalid/expired token: 400/401 response
        def verify_partner_token(token_value)
          response = make_tokeninfo_request(token_value)
          analyze_gcp_response(response)
        end

        def make_tokeninfo_request(token_value)
          # URL encode the token value for query parameter
          encoded_token = CGI.escape(token_value)
          url = "#{TOKENINFO_ENDPOINT}?access_token=#{encoded_token}"

          make_request(url, method: :get)
        end

        def analyze_gcp_response(response)
          case response.code.to_i
          when 200
            token_response(:active)

          when 400, 401
            # Invalid or expired token
            token_response(:inactive)

          when 429
            # GCP rate limiting
            raise RateLimitError, "GCP tokeninfo rate limited: #{response.code}"

          when 500, 502, 503, 504
            # GCP service errors - should retry
            raise NetworkError, "GCP service error: #{response.code}"

          else
            # Other unexpected responses
            token_response(:unknown)
          end
        end
      end
    end
  end
end
