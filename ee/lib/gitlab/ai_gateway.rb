# frozen_string_literal: true

module Gitlab
  module AiGateway
    ForbiddenError = Class.new(StandardError)

    FEATURE_FLAG_CACHE_KEY = "gitlab_ai_gateway_feature_flags"

    def self.url
      ENV['AI_GATEWAY_URL'] || "#{::CloudConnector::Config.base_url}/ai"
    end

    def self.access_token_url
      base_url = ENV['AI_GATEWAY_URL'] || "#{::CloudConnector::Config.base_url}/auth"

      "#{base_url}/v1/code/user_access_token"
    end

    # Exposes the state of a feature flag to the AI Gateway code.
    #
    # name - The name of the feature flag, e.g. `my_feature`.
    # args - Any additional arguments to pass to `Feature.enabled?`. This allows
    #        you to check if a flag is enabled for a particular user.
    def self.push_feature_flag(name, *args, **kwargs)
      enabled = Feature.enabled?(name, *args, **kwargs)

      return unless enabled

      enabled_feature_flags.append(name)
    end

    # Appended feature flags to the current context.
    # We use SafeRequestStore for the context management which refresh the cache per API request or Sidekiq job run.
    # See https://gitlab.com/gitlab-org/gitlab/-/blob/master/gems/gitlab-safe_request_store/README.md
    def self.enabled_feature_flags
      Gitlab::SafeRequestStore.fetch(FEATURE_FLAG_CACHE_KEY) { [] }
    end

    def self.headers(user:, service:, agent: nil, lsp_version: nil)
      {
        'X-Gitlab-Authentication-Type' => 'oidc',
        'Authorization' => "Bearer #{service.access_token(user)}",
        'X-Gitlab-Feature-Enabled-By-Namespace-Ids' => service.enabled_by_namespace_ids(user).join(','),
        'Content-Type' => 'application/json',
        'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id,
        # Forward the request time to the model gateway to calculate latency
        'X-Gitlab-Rails-Send-Start' => Time.now.to_f.to_s,
        'x-gitlab-enabled-feature-flags' => enabled_feature_flags.uniq.join(',')
      }.merge(Gitlab::CloudConnector.headers(user))
        .tap do |result|
          result['User-Agent'] = agent if agent # Forward the User-Agent on to the model gateway

          if lsp_version
            # Forward the X-Gitlab-Language-Server-Version on to the model gateway
            result['X-Gitlab-Language-Server-Version'] = lsp_version
          end

          # Pass the distrubted tracing LangSmith header to AI Gateway.
          result.merge!(Langsmith::RunHelpers.to_headers) if Langsmith::RunHelpers.enabled?
        end
    end
  end
end
