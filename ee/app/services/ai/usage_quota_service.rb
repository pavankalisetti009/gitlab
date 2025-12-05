# frozen_string_literal: true

module Ai
  class UsageQuotaService < BaseService
    include Gitlab::Utils::StrongMemoize

    def initialize(user:, namespace: nil)
      @user = user
      @namespace = namespace
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

      response = ::Gitlab::SubscriptionPortal::Client.verify_usage_quota(**params)

      if response[:success]
        ServiceResponse.success
      else
        ServiceResponse.error(message: "Usage quota exceeded", reason: :usage_quota_exceeded)
      end
    rescue StandardError
      ServiceResponse.error(message: "Error while fetching usage quota", reason: :service_error)
    end

    private

    attr_reader :user, :namespace

    def root_namespace
      return namespace if namespace

      user.user_preference.duo_default_namespace_with_fallback
    end
    strong_memoize_attr :root_namespace
  end
end
