# frozen_string_literal: true

module Gitlab
  module Middleware
    class JsonValidation
      BodySizeExceededError = Class.new(StandardError)

      DEFAULT_OPTIONS = {
        # Rack::Utils uses a depth of 32 by default
        max_depth: ENV.fetch('GITLAB_JSON_MAX_DEPTH', 32).to_i,
        max_array_size: ENV.fetch('GITLAB_JSON_MAX_ARRAY_SIZE', 1000).to_i,
        max_hash_size: ENV.fetch('GITLAB_JSON_MAX_HASH_SIZE', 1000).to_i,
        max_total_elements: ENV.fetch('GITLAB_JSON_MAX_TOTAL_ELEMENTS', 10000).to_i,
        # Disabled by default because some endpoints upload large payloads
        max_json_size_bytes: ENV.fetch('GITLAB_JSON_MAX_JSON_SIZE_BYTES', 0).to_i,
        # Supported modes: enforced, disabled, logging
        mode: ENV.fetch('GITLAB_JSON_VALIDATION_MODE', 'logging').downcase.to_sym
      }.freeze

      def initialize(app, options = {})
        @app = app
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def call(env)
        return @app.call(env) if disabled?

        request = Rack::Request.new(env)

        return @app.call(env) unless json_request?(request)

        allow_if_validated(env, request)
      end

      def allow_if_validated(env, request)
        validate_json_request!(env, request)
        @app.call(env)
      rescue BodySizeExceededError, ::Gitlab::Json::StreamValidator::LimitExceededError => ex
        log_exceeded(ex, request)

        return error_response(ex, 400) unless logging?

        @app.call(env)
      end

      private

      def log_exceeded(ex, request)
        payload = @options.merge({
          class_name: self.class.name,
          message: ex.to_s,
          method: request.request_method,
          path: request.path,
          # Manually add the status code here because the original requests are not
          # logged in production_json.log or api_json.log.
          status: 400,
          ua: request.env["HTTP_USER_AGENT"],
          remote_ip: request.ip
        })
        ::Gitlab::InstrumentationHelper.add_instrumentation_data(payload)
        Gitlab::AppLogger.warn(payload)
      end

      def disabled?
        @options[:mode] == :disabled
      end

      def logging?
        @options[:mode] == :logging
      end

      def json_request?(request)
        # Ensure we get synonyms registered in config/initializers/mime_types
        Mime[:json] == request.media_type
      end

      # JSON Validation using Oj streaming
      def validate_json_request!(_env, request)
        body = request.body.read
        request.body.rewind

        return if body.empty?

        if @options[:max_json_size_bytes].to_i > 0 && body.bytesize > @options[:max_json_size_bytes]
          raise BodySizeExceededError, "JSON body too large: #{body.bytesize} bytes"
        end

        handler = ::Gitlab::Json::StreamValidator.new(@options)
        ::Oj.sc_parse(handler, body)
      # Could be either a Oj::ParseError or an EncodingError depending on
      # whether mimic_JSON has been called.
      rescue Oj::ParseError, EncodingError
        # If this string isn't valid JSON, let it go
      end

      def error_response(error, status)
        message = case error
                  when ::Gitlab::Json::StreamValidator::DepthLimitError
                    "Parameters nested too deeply"
                  when ::Gitlab::Json::StreamValidator::ArraySizeLimitError
                    "Array parameter too large"
                  when ::Gitlab::Json::StreamValidator::HashSizeLimitError
                    "Hash parameter too large"
                  when ::Gitlab::Json::StreamValidator::ElementCountLimitError
                    "Too many total parameters"
                  when BodySizeExceededError
                    "JSON body too large"
                  else
                    "Invalid JSON: limit exceeded"
                  end

        [
          status,
          { 'Content-Type' => 'application/json' },
          [{ error: message }.to_json]
        ]
      end
    end
  end
end
