# frozen_string_literal: true

module Ai
  module AmazonQ
    class << self
      def feature_available?
        License.feature_available?(:amazon_q) && !duo_features_available?
      end

      def connected?
        return false unless feature_available?

        ai_settings.amazon_q_ready
      end

      def enabled?
        feature_available? && connected?
      end

      def should_block_service_account?(availability:)
        availability == "never_on"
      end

      def ensure_service_account_blocked!(current_user:, service_account: nil)
        service_account ||= ai_settings.amazon_q_service_account_user

        return ServiceResponse.success(message: "Service account not found. Nothing to do.") unless service_account

        if service_account.blocked?
          ServiceResponse.success(message: "Service account already blocked. Nothing to do.")
        else
          ServiceResponse.from_legacy_hash(::Users::BlockService.new(current_user).execute(service_account))
        end
      end

      def ensure_service_account_unblocked!(current_user:, service_account: nil)
        service_account ||= ai_settings.amazon_q_service_account_user

        return ServiceResponse.error(message: "Service account not found.") unless service_account

        if service_account.blocked?
          ServiceResponse.from_legacy_hash(::Users::UnblockService.new(current_user).execute(service_account))
        else
          ServiceResponse.success(message: "Service account already unblocked. Nothing to do.")
        end
      end

      private

      def ai_settings
        Ai::Setting.instance
      end

      def duo_features_available?
        ::GitlabSubscriptions::AddOnPurchase.by_namespace(nil).for_duo_pro_or_duo_enterprise.active.exists?
      end
    end
  end
end
