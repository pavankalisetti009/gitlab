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
      return ServiceResponse.error(message: "User is required", reason: :user_missing) unless user

      params = { user_id: user.id }

      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        return ServiceResponse.error(message: "Namespace is required", reason: :namespace_missing) unless root_namespace
        return ServiceResponse.success if skip_quota_check_for_team_members?

        params[:root_namespace_id] = root_namespace.id
        params[:plan_key] = root_namespace.actual_plan_name
      else
        params[:unique_instance_id] = self_managed_instance_identifier
        params[:plan_key] = License.current&.trial?.to_s
      end

      feature_metadata = ::Gitlab::SubscriptionPortal::FeatureMetadata.for(:dap_feature_legacy)
      response = ::Gitlab::SubscriptionPortal::Client.verify_usage_quota(
        @event_type,
        feature_metadata,
        **params
      )

      # To adhere to GitLab SLA we treat every error as success if it's not related to payment error
      # This also on a parity how we make this check in AIGW/DWS
      if response.dig("data", "errors")&.include?("402")
        ServiceResponse.error(message: "Usage quota exceeded", reason: :usage_quota_exceeded)
      else
        ServiceResponse.success
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
      if namespace && user.allowed_by_namespace_ids(ai_feature).include?(namespace.root_ancestor.id)
        namespace.root_ancestor
      else
        user.user_preference.duo_default_namespace_with_fallback
      end
    end
    strong_memoize_attr :root_namespace

    def self_managed_instance_identifier
      if License.current&.trial?
        Gitlab::GlobalAnonymousId.instance_uuid
      else
        Gitlab::GlobalAnonymousId.instance_id
      end
    end

    def skip_quota_check_for_team_members?
      Feature.disabled?(:enable_quota_check_for_team_members, user) && user.gitlab_team_member?
    end
  end
end
