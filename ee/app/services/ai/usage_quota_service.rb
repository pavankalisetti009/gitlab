# frozen_string_literal: true

module Ai
  class UsageQuotaService < BaseService
    include Gitlab::Utils::StrongMemoize

    def initialize(ai_feature:, user:, namespace: nil, event_type: :rails_on_ui_check)
      @ai_feature = ai_feature
      @user = user
      @namespace = namespace
      @event_type = event_type
    end

    def execute
      return ServiceResponse.success unless Feature.enabled?(:usage_quota_left_check, user)
      return ServiceResponse.error(message: "User is required", reason: :user_missing) unless user

      params = { user_id: user.id }

      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        return ServiceResponse.error(message: "Namespace is required", reason: :namespace_missing) unless root_namespace

        params[:root_namespace_id] = root_namespace.id
      else
        params[:unique_instance_id] = Gitlab::GlobalAnonymousId.instance_uuid
      end

      feature_metadata = ::Gitlab::SubscriptionPortal::FeatureMetadata.for(:dap_feature_legacy)
      response = ::Gitlab::SubscriptionPortal::Client.verify_usage_quota(
        @event_type,
        feature_metadata,
        **params
      )

      if response[:success]
        ServiceResponse.success
      else
        ServiceResponse.error(message: "Usage quota exceeded", reason: :usage_quota_exceeded)
      end
    rescue StandardError
      # To adhere to GitLab SLA for this specific domain we should process the request as successful
      # and not block user usage of AI Features
      ServiceResponse.success
    end

    private

    attr_reader :user, :namespace, :ai_feature

    def root_namespace
      # If the user can invoke the feature in the current context, check quota on `namespace`, else use fallback
      return namespace if namespace && user.allowed_by_namespace_ids(ai_feature).include?(namespace.id)

      user.user_preference.duo_default_namespace_with_fallback
    end
    strong_memoize_attr :root_namespace
  end
end
