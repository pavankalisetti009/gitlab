# frozen_string_literal: true

module Security
  module SecretDetection
    module PartnerTokens
      class BaseClient
        include Gitlab::Utils::StrongMemoize

        NetworkError = Class.new(StandardError)
        ResponseError = Class.new(StandardError)
        RateLimitError = Class.new(ResponseError)

        TokenStatus = Struct.new(:status, :metadata, keyword_init: true) do
          ::Security::TokenStatus::STATUSES.each_key do |state|
            define_method(:"#{state}?") do
              status == state
            end
          end
        end

        def verify_token(token_value)
          return token_response(:unknown) unless valid_format?(token_value)

          verify_partner_token(token_value)

        rescue RateLimitError, NetworkError => e
          # Let the worker handle rate limit retries
          raise e
        rescue ResponseError => e
          ::Gitlab::ErrorTracking.log_exception(e)
          # Response parsing errors typically don't benefit from retry
          token_response(:unknown)
        end

        def valid_format?(token_value)
          raise NotImplementedError, 'Subclasses must implement valid_format?'
        end

        def verify_partner_token(token_value)
          raise NotImplementedError, 'Subclasses must implement verify_partner_token'
        end

        protected

        def make_request(url, method: :get, headers: {}, body: nil)
          case method.to_sym
          when :get
            Integrations::Clients::HTTP.get(url, headers: headers)
          when :post
            Integrations::Clients::HTTP.post(url, body: body, headers: headers)
          end
        rescue *Gitlab::HTTP::HTTP_TIMEOUT_ERRORS => e
          raise NetworkError, "Request timeout: #{e.message}"
        rescue Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
          raise NetworkError, "Connection error: #{e.message}"
        rescue Net::HTTPError => e
          raise NetworkError, "HTTP error: #{e.message}"
        rescue StandardError => e
          raise NetworkError, "Unexpected error: #{e.message}"
        end

        def parse_json_response(response)
          return {} if response.body.blank?

          ::Gitlab::Json.parse(response.body)
        rescue JSON::ParserError => e
          raise ResponseError, "Invalid JSON response: #{e.message}"
        end

        def parse_xml_response(response)
          return Nokogiri::XML('<empty/>') if response.body.blank?

          Nokogiri::XML(response.body, &:strict)
        rescue Nokogiri::XML::SyntaxError => e
          raise ResponseError, "Invalid XML response: #{e.message}"
        end

        def token_response(status)
          TokenStatus.new(
            status: status,
            metadata: build_metadata
          )
        end

        private

        def build_metadata
          {
            partner: partner_name.upcase,
            verified_at: Time.current.iso8601
          }
        end

        def partner_name
          @partner_name ||= self.class.name.demodulize.sub('Client', '').downcase
        end
        strong_memoize_attr :partner_name
      end
    end
  end
end
