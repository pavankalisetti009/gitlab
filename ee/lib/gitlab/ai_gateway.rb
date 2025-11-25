# frozen_string_literal: true

module Gitlab
  module AiGateway
    ForbiddenError = Class.new(StandardError)
    ClientError = Class.new(StandardError)
    ServerError = Class.new(StandardError)

    FEATURE_FLAG_CACHE_KEY = "gitlab_ai_gateway_feature_flags"
    CURRENT_CONTEXT_CACHE_KEY = "gitlab_ai_gateway_current_context"
    ACCESS_TOKEN_PATH = "/v1/code/user_access_token"

    def self.url
      self_hosted_url || cloud_connector_url
    end

    def self.cloud_connector_url
      development_url || "#{::CloudConnector::Config.base_url}/ai"
    end

    def self.cloud_connector_auth_url
      development_url || "#{::CloudConnector::Config.base_url}/auth"
    end

    def self.access_token_url(code_completions_feature_setting)
      base_url = if code_completions_feature_setting&.vendored?
                   cloud_connector_auth_url
                 else
                   self_hosted_url || cloud_connector_auth_url
                 end

      "#{base_url}#{ACCESS_TOKEN_PATH}"
    end

    def self.self_hosted_url
      ::Ai::Setting.instance&.ai_gateway_url
    end

    def self.development_url
      ENV["DEVELOPMENT_AI_GATEWAY_URL"]
    end

    def self.has_self_hosted_ai_gateway?
      !self_hosted_url.blank?
    end

    def self.enabled_instance_verbose_ai_logs
      ::Ai::Setting.instance&.enabled_instance_verbose_ai_logs.to_s || ''
    end

    def self.timeout
      ::Ai::Setting.instance&.ai_gateway_timeout_seconds&.seconds || 60.seconds
    end

    # Exposes the state of a feature flag to the AI Gateway code.
    #
    # name - The name of the feature flag, e.g. `my_feature`.
    # args - Any additional arguments to pass to `Feature.enabled?`. This allows
    #        you to check if a flag is enabled for a particular user.
    def self.push_feature_flag(name, *args, **kwargs)
      enabled = Feature.enabled?(name, *args, **kwargs)

      return unless enabled

      # We don't want the `expanded_ai_logging` feature flag to be pushed to AIGW
      # on any kind of self-managed instance (including instances running Self-hosted Duo)
      # Expanded logging will work via `enabled_instance_verbose_ai_logs` for self-hosted Duo
      # And, expanded logging should not work at all for self-managed instances connected to cloud AIGW.
      # Essentially, `expanded_ai_logging` FF should only work on gitlab.com, for
      # debugging purposes.
      return if expanded_ai_logging_on_self_managed?(name)

      enabled_feature_flags.append(name)
    end

    def self.current_context
      Gitlab::SafeRequestStore.fetch(CURRENT_CONTEXT_CACHE_KEY) { {} }
    end

    # Appended feature flags to the current context.
    # We use SafeRequestStore for the context management which refresh the cache per API request or Sidekiq job run.
    # See https://gitlab.com/gitlab-org/gitlab/-/blob/master/gems/gitlab-safe_request_store/README.md
    def self.enabled_feature_flags
      Gitlab::SafeRequestStore.fetch(FEATURE_FLAG_CACHE_KEY) { [] }
    end

    def self.expanded_ai_logging_on_self_managed?(name)
      # gitlab_com_subscriptions is only available on GitLab.com (SaaS)
      # so its absence indicates a self-managed instance
      self_managed_instance = !::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

      name.to_sym == :expanded_ai_logging && self_managed_instance
    end

    def self.headers(user:, unit_primitive_name:, ai_feature_name: unit_primitive_name, agent: nil, lsp_version: nil)
      # Make interface flexible for the caller allowing both Symbol and String for `unit_primitive_name`.
      # At the same time, operate with the deterministic type (Symbol) within the implementation.
      unit_primitive_name = unit_primitive_name.to_sym
      ai_feature_name = ai_feature_name.to_sym

      {
        'X-Gitlab-Authentication-Type' => 'oidc',
        'Authorization' => "Bearer #{cloud_connector_token(unit_primitive_name, user)}",
        'Content-Type' => 'application/json',
        'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id,
        # Forward the request time to the model gateway to calculate latency
        'X-Gitlab-Rails-Send-Start' => Time.now.to_f.to_s
      }.merge(public_headers(user: user, ai_feature_name: ai_feature_name, unit_primitive_name: unit_primitive_name))
        .tap do |result|
          result['User-Agent'] = agent if agent # Forward the User-Agent on to the model gateway
          if current_context[:x_gitlab_client_type]
            result['X-Gitlab-Client-Type'] = current_context[:x_gitlab_client_type]
          end

          if current_context[:x_gitlab_client_version]
            result['X-Gitlab-Client-Version'] = current_context[:x_gitlab_client_version]
          end

          if current_context[:x_gitlab_client_name]
            result['X-Gitlab-Client-Name'] = current_context[:x_gitlab_client_name]
          end

          result['X-Gitlab-Interface'] = current_context[:x_gitlab_interface] if current_context[:x_gitlab_interface]

          if lsp_version
            # Forward the X-Gitlab-Language-Server-Version on to the model gateway
            result['X-Gitlab-Language-Server-Version'] = lsp_version
          end

          # Pass the distrubted tracing LangSmith header to AI Gateway.
          result.merge!(Langsmith::RunHelpers.to_headers) if Langsmith::RunHelpers.enabled?
        end
    end

    def self.public_headers(user:, ai_feature_name:, unit_primitive_name:, feature_setting: nil)
      auth_response = user&.allowed_to_use(ai_feature_name, unit_primitive_name: unit_primitive_name,
        feature_setting: feature_setting)
      enablement_type = auth_response&.enablement_type || ''
      namespace_ids = auth_response&.namespace_ids || []

      {
        'x-gitlab-feature-enablement-type' => enablement_type,
        'x-gitlab-enabled-feature-flags' => enabled_feature_flags.uniq.join(','),
        'x-gitlab-enabled-instance-verbose-ai-logs' => enabled_instance_verbose_ai_logs,
        'X-Gitlab-Is-Team-Member' =>
          (::Gitlab::Tracking::StandardContext.new.gitlab_team_member?(user&.id) || false).to_s
      }.merge(::CloudConnector.ai_headers(user, namespace_ids: namespace_ids))
    end

    def self.cloud_connector_token(unit_primitive_name, user)
      # Until https://gitlab.com/groups/gitlab-org/-/epics/15639 is complete, we generate service
      # definitions for each UP, so passing the service name here should be safe, even if `service`
      # is not defined explicitly.
      ::CloudConnector::Tokens.get(unit_primitive: unit_primitive_name, resource: user)
    end
  end
end
