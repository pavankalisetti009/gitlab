# frozen_string_literal: true

module ExternalStatusChecks
  class DispatchService
    REQUEST_BODY_SIZE_LIMIT = 25.megabytes

    attr_reader :rule, :data

    def initialize(rule, data)
      @rule = rule
      @data = data
    end

    def execute
      body = Gitlab::Json::LimitedEncoder.encode(data, limit: REQUEST_BODY_SIZE_LIMIT)
      headers = { 'Content-Type': 'application/json' }
      headers['X-GitLab-Signature'] = OpenSSL::HMAC.hexdigest('sha256', rule.shared_secret, body) if rule.hmac?

      response = Gitlab::HTTP.post(
        rule.external_url,
        headers: headers,
        body: Gitlab::Json::LimitedEncoder.encode(data, limit: REQUEST_BODY_SIZE_LIMIT))

      if response.success?
        ServiceResponse.success(payload: { rule: rule }, http_status: response.code)
      else
        ServiceResponse.error(message: 'Service responded with an error', http_status: response.code)
      end
    end
  end
end
